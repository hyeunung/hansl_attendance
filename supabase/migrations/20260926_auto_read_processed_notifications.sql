-- 요청 건이 처리(승인/반려/완료/삭제)되면 해당 건의 "처리 요청" 알림을 모든 수신자에 대해 자동 읽음 처리
-- 매칭 기준: notifications.data->>'type' (세부 종류) + data의 참조 키

-- 1. 공통 함수
create or replace function public.mark_notifications_read_by_ref(
  p_types text[],
  p_key text,
  p_value text
) returns void
language sql
security definer
set search_path = public
as $$
  update public.notifications
     set is_read = true,
         read_at = now()
   where is_read = false
     and data->>'type' = any(p_types)
     and data->>p_key = p_value;
$$;

revoke execute on function public.mark_notifications_read_by_ref(text[], text, text) from public, anon, authenticated;

create index if not exists idx_notifications_unread_data_type
  on public.notifications ((data->>'type'))
  where is_read = false;

-- 2. 연차 (leave.status: pending → approved/rejected, 또는 삭제)
create or replace function public.trg_leave_auto_read_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.mark_notifications_read_by_ref(array['leave_request'], 'leave_id', old.id::text);
    return old;
  end if;
  if new.status is distinct from old.status and coalesce(new.status, 'pending') <> 'pending' then
    perform public.mark_notifications_read_by_ref(array['leave_request'], 'leave_id', new.id::text);
  end if;
  return new;
end;
$$;

drop trigger if exists leave_auto_read_notifications on public.leave;
create trigger leave_auto_read_notifications
  after update of status or delete on public.leave
  for each row execute function public.trg_leave_auto_read_notifications();

-- 3. 출장 (business_trips.approval_status)
create or replace function public.trg_business_trip_auto_read_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.mark_notifications_read_by_ref(array['business_trip'], 'business_trip_id', old.id::text);
    return old;
  end if;
  if new.approval_status is distinct from old.approval_status and coalesce(new.approval_status, 'pending') <> 'pending' then
    perform public.mark_notifications_read_by_ref(array['business_trip'], 'business_trip_id', new.id::text);
  end if;
  return new;
end;
$$;

drop trigger if exists business_trip_auto_read_notifications on public.business_trips;
create trigger business_trip_auto_read_notifications
  after update of approval_status or delete on public.business_trips
  for each row execute function public.trg_business_trip_auto_read_notifications();

-- 4. 발주 (1차 승인/반려 → 신규 구매 요청 알림, 최종 승인/반려·1차 반려 → 최종승인 요청 알림, 삭제 → 둘 다)
create or replace function public.trg_purchase_auto_read_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    if old.purchase_order_number is not null then
      perform public.mark_notifications_read_by_ref(array['purchase_requests', 'final_approval_request'], 'purchase_order_number', old.purchase_order_number);
    end if;
    return old;
  end if;
  if new.purchase_order_number is null then
    return new;
  end if;
  if new.middle_manager_status is distinct from old.middle_manager_status
     and coalesce(new.middle_manager_status, 'pending') <> 'pending' then
    perform public.mark_notifications_read_by_ref(array['purchase_requests'], 'purchase_order_number', new.purchase_order_number);
  end if;
  if (new.final_manager_status is distinct from old.final_manager_status and coalesce(new.final_manager_status, 'pending') <> 'pending')
     or (new.middle_manager_status is distinct from old.middle_manager_status and new.middle_manager_status = 'rejected') then
    perform public.mark_notifications_read_by_ref(array['final_approval_request'], 'purchase_order_number', new.purchase_order_number);
  end if;
  return new;
end;
$$;

drop trigger if exists purchase_auto_read_notifications on public.purchase_requests;
create trigger purchase_auto_read_notifications
  after update of final_manager_status, middle_manager_status or delete on public.purchase_requests
  for each row execute function public.trg_purchase_auto_read_notifications();

-- 5. 차량 요청 (vehicle_requests.approval_status, 매칭 키 vehicle_code)
create or replace function public.trg_vehicle_auto_read_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    if old.vehicle_code is not null then
      perform public.mark_notifications_read_by_ref(array['vehicle_requested'], 'vehicle_code', old.vehicle_code);
    end if;
    return old;
  end if;
  if new.vehicle_code is not null
     and new.approval_status is distinct from old.approval_status
     and coalesce(new.approval_status, 'pending') <> 'pending' then
    perform public.mark_notifications_read_by_ref(array['vehicle_requested'], 'vehicle_code', new.vehicle_code);
  end if;
  return new;
end;
$$;

drop trigger if exists vehicle_auto_read_notifications on public.vehicle_requests;
create trigger vehicle_auto_read_notifications
  after update of approval_status or delete on public.vehicle_requests
  for each row execute function public.trg_vehicle_auto_read_notifications();

-- 6. 카드 사용 요청 (card_usages.approval_status, 매칭 키 card_usage_id - 웹에서 알림 발송 시 포함)
create or replace function public.trg_card_usage_auto_read_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.mark_notifications_read_by_ref(array['card_usage_requested'], 'card_usage_id', old.id::text);
    return old;
  end if;
  if new.approval_status is distinct from old.approval_status and coalesce(new.approval_status, 'pending') <> 'pending' then
    perform public.mark_notifications_read_by_ref(array['card_usage_requested'], 'card_usage_id', new.id::text);
  end if;
  return new;
end;
$$;

drop trigger if exists card_usage_auto_read_notifications on public.card_usages;
create trigger card_usage_auto_read_notifications
  after update of approval_status or delete on public.card_usages
  for each row execute function public.trg_card_usage_auto_read_notifications();

-- 7. 신규 업체 문의 (support_inquires.status → resolved, 매칭 키 inquiryId)
--    inquiry_message는 요청자에게 가는 답변 알림(미확인 답변 배지 기준)이므로 제외
create or replace function public.trg_inquiry_auto_read_notifications()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if tg_op = 'DELETE' then
    perform public.mark_notifications_read_by_ref(array['new_vendor_inquiry'], 'inquiryId', old.id::text);
    return old;
  end if;
  if new.status is distinct from old.status and new.status = 'resolved' then
    perform public.mark_notifications_read_by_ref(array['new_vendor_inquiry'], 'inquiryId', new.id::text);
  end if;
  return new;
end;
$$;

drop trigger if exists inquiry_auto_read_notifications on public.support_inquires;
create trigger inquiry_auto_read_notifications
  after update of status or delete on public.support_inquires
  for each row execute function public.trg_inquiry_auto_read_notifications();
