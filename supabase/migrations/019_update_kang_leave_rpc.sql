-- RPC 함수로 강영은님의 연차 타입 수정
CREATE OR REPLACE FUNCTION update_kang_leave_type()
RETURNS void AS $$
BEGIN
  UPDATE leave 
  SET type = 'half_afternoon'
  WHERE id = 441;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;