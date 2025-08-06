#!/usr/bin/env python3
"""
HANSL Flutter App Dependency Security and Safety Analysis
Analyzes pubspec.yaml and pubspec.lock for security vulnerabilities and best practices
"""

import yaml
import json
import re
from datetime import datetime, timedelta
from typing import Dict, List, Any, Optional

class DependencyAnalyzer:
    def __init__(self):
        self.critical_issues = []
        self.high_issues = []
        self.medium_issues = []
        self.low_issues = []
        self.recommendations = []
        
        # Known vulnerable versions or packages (simplified - in production use actual CVE database)
        self.known_vulnerabilities = {
            'http': {
                'versions': ['<0.13.5'],
                'cve': 'CVE-2021-XXXX',
                'description': 'HTTP package versions before 0.13.5 may have security issues'
            }
        }
        
        # Packages with known security best practices
        self.security_packages = {
            'crypto': 'Cryptographic operations',
            'encrypt': 'Encryption/decryption',
            'flutter_secure_storage': 'Secure local storage',
            'local_auth': 'Biometric authentication',
            'permission_handler': 'Permission management'
        }
        
        # Performance-critical packages
        self.performance_packages = {
            'cached_network_image': 'Image caching and optimization',
            'flutter_cache_manager': 'Advanced caching',
            'sqflite': 'Local database performance',
            'hive': 'Fast local storage'
        }

    def load_pubspec_yaml(self, file_path: str) -> Dict[str, Any]:
        """Load and parse pubspec.yaml"""
        try:
            with open(file_path, 'r', encoding='utf-8') as file:
                return yaml.safe_load(file)
        except Exception as e:
            self.critical_issues.append(f"Failed to load pubspec.yaml: {e}")
            return {}

    def parse_pubspec_lock(self, file_path: str) -> Dict[str, Any]:
        """Parse pubspec.lock for exact versions"""
        try:
            with open(file_path, 'r', encoding='utf-8') as file:
                content = file.read()
                # Simple parsing of pubspec.lock
                packages = {}
                current_package = None
                
                for line in content.split('\n'):
                    line = line.strip()
                    if line.endswith(':') and not line.startswith(' '):
                        current_package = line[:-1]
                        packages[current_package] = {}
                    elif current_package and 'version:' in line:
                        version = line.split('version:')[1].strip().strip('"')
                        packages[current_package]['version'] = version
                        
                return packages
        except Exception as e:
            self.critical_issues.append(f"Failed to parse pubspec.lock: {e}")
            return {}

    def analyze_security_vulnerabilities(self, dependencies: Dict[str, Any], lock_packages: Dict[str, Any]):
        """Analyze for known security vulnerabilities"""
        print("🔍 Analyzing security vulnerabilities...")
        
        for package_name, constraint in dependencies.items():
            if package_name in self.known_vulnerabilities:
                vuln = self.known_vulnerabilities[package_name]
                actual_version = lock_packages.get(package_name, {}).get('version', 'unknown')
                
                self.high_issues.append({
                    'package': package_name,
                    'issue': 'Potential security vulnerability',
                    'description': vuln['description'],
                    'current_version': actual_version,
                    'recommendation': f"Update to latest version to address {vuln.get('cve', 'security issues')}"
                })

    def analyze_outdated_packages(self, lock_packages: Dict[str, Any]):
        """Analyze for potentially outdated packages"""
        print("📅 Analyzing package freshness...")
        
        # Packages that are critical to keep updated
        critical_packages = [
            'firebase_core', 'firebase_messaging', 'supabase_flutter', 
            'flutter_dotenv', 'http', 'shared_preferences'
        ]
        
        for package in critical_packages:
            if package in lock_packages:
                version = lock_packages[package].get('version', 'unknown')
                # Simple heuristic: if version is < 1.0, it might need attention
                if version != 'unknown':
                    try:
                        major_version = int(version.split('.')[0])
                        if major_version == 0:
                            self.medium_issues.append({
                                'package': package,
                                'issue': 'Pre-1.0 version',
                                'current_version': version,
                                'description': f'{package} is at version {version} (pre-1.0)',
                                'recommendation': 'Monitor for stability and security updates'
                            })
                    except:
                        pass

    def analyze_dependency_conflicts(self, dependencies: Dict[str, Any]):
        """Analyze for potential dependency conflicts"""
        print("⚔️ Analyzing dependency conflicts...")
        
        # Check for multiple similar packages
        similar_packages = [
            ['http', 'dio'],  # HTTP clients
            ['shared_preferences', 'hive', 'sqflite'],  # Storage
            ['provider', 'bloc', 'riverpod'],  # State management
        ]
        
        for group in similar_packages:
            found_packages = [pkg for pkg in group if pkg in dependencies]
            if len(found_packages) > 1:
                self.medium_issues.append({
                    'packages': found_packages,
                    'issue': 'Multiple similar packages',
                    'description': f'Found multiple packages that serve similar purposes: {", ".join(found_packages)}',
                    'recommendation': 'Consider consolidating to reduce bundle size and complexity'
                })

    def analyze_unused_dependencies(self, pubspec_data: Dict[str, Any]):
        """Analyze for potentially unused dependencies"""
        print("🗑️ Analyzing unused dependencies...")
        
        dependencies = pubspec_data.get('dependencies', {})
        dev_dependencies = pubspec_data.get('dev_dependencies', {})
        
        # Packages that are often added but not used
        potentially_unused = []
        
        # This is a simplified check - real analysis would scan source code
        optional_packages = [
            'cupertino_icons',  # Only needed if using Cupertino icons
            'package_info_plus',  # Only if app info is displayed
        ]
        
        for package in optional_packages:
            if package in dependencies:
                self.low_issues.append({
                    'package': package,
                    'issue': 'Potentially unused dependency',
                    'description': f'{package} may not be necessary if features are not used',
                    'recommendation': 'Audit usage and remove if not needed'
                })

    def analyze_security_best_practices(self, dependencies: Dict[str, Any]):
        """Analyze security best practices"""
        print("🛡️ Analyzing security best practices...")
        
        # Check for security-related packages
        has_secure_storage = any(pkg in dependencies for pkg in ['flutter_secure_storage', 'keychain', 'android_keystore'])
        has_encryption = any(pkg in dependencies for pkg in ['crypto', 'encrypt', 'pointycastle'])
        has_certificate_pinning = any(pkg in dependencies for pkg in ['certificate_pinning', 'dio_certificate_pinning'])
        
        if not has_secure_storage:
            self.medium_issues.append({
                'issue': 'No secure storage detected',
                'description': 'No secure storage package found for sensitive data',
                'recommendation': 'Consider adding flutter_secure_storage for storing sensitive data like tokens'
            })
        
        # Check for .env file in assets (security concern)
        if '.env' in str(dependencies.get('flutter', {}).get('assets', [])):
            self.high_issues.append({
                'issue': 'Environment file in assets',
                'description': '.env file is included in app assets (visible to users)',
                'recommendation': 'Remove .env from assets and use build-time environment injection'
            })

    def analyze_performance_implications(self, dependencies: Dict[str, Any], lock_packages: Dict[str, Any]):
        """Analyze performance implications of dependencies"""
        print("⚡ Analyzing performance implications...")
        
        # Large packages that might impact app size
        potentially_large_packages = {
            'firebase_core': 'Firebase adds significant size',
            'table_calendar': 'Calendar widgets can be heavy',
            'dropdown_button2': 'UI packages add weight'
        }
        
        large_count = 0
        for package, description in potentially_large_packages.items():
            if package in dependencies:
                large_count += 1
                
        if large_count > 3:
            self.medium_issues.append({
                'issue': 'Multiple large dependencies',
                'description': f'App includes {large_count} potentially large packages',
                'recommendation': 'Monitor app size and consider alternatives for heavy packages'
            })
        
        # Missing performance packages
        performance_missing = []
        if 'cached_network_image' not in dependencies and 'http' in dependencies:
            performance_missing.append('cached_network_image for image caching')
        
        if performance_missing:
            self.recommendations.append({
                'category': 'Performance',
                'suggestion': f'Consider adding: {", ".join(performance_missing)}',
                'benefit': 'Improved app performance and user experience'
            })

    def analyze_maintenance_burden(self, dependencies: Dict[str, Any]):
        """Analyze maintenance burden"""
        print("🔧 Analyzing maintenance burden...")
        
        dependency_count = len(dependencies)
        
        if dependency_count > 20:
            self.medium_issues.append({
                'issue': 'High dependency count',
                'description': f'App has {dependency_count} dependencies',
                'recommendation': 'Review dependencies periodically and remove unused ones'
            })
        
        # Check for deprecated packages (simplified check)
        potentially_deprecated = []
        # This would normally check against a database of deprecated packages
        
        if potentially_deprecated:
            self.high_issues.append({
                'issue': 'Deprecated packages',
                'packages': potentially_deprecated,
                'recommendation': 'Replace deprecated packages with maintained alternatives'
            })

    def generate_recommendations(self, pubspec_data: Dict[str, Any]):
        """Generate overall recommendations"""
        print("💡 Generating recommendations...")
        
        # Flutter version check
        sdk_version = pubspec_data.get('environment', {}).get('sdk', '')
        if '^3.8.0' in sdk_version:
            self.recommendations.append({
                'category': 'Flutter Version',
                'suggestion': 'Using Flutter 3.8.0+ is good - modern and stable',
                'benefit': 'Latest features and security updates'
            })
        
        # Development tools
        dev_deps = pubspec_data.get('dev_dependencies', {})
        if 'flutter_lints' in dev_deps:
            self.recommendations.append({
                'category': 'Code Quality',
                'suggestion': 'flutter_lints is configured - excellent for code quality',
                'benefit': 'Consistent code style and best practices'
            })
            
        # Security recommendations
        self.recommendations.append({
            'category': 'Security',
            'suggestion': 'Implement dependency scanning in CI/CD pipeline',
            'benefit': 'Automated vulnerability detection'
        })
        
        self.recommendations.append({
            'category': 'Performance',
            'suggestion': 'Monitor app bundle size after each dependency addition',
            'benefit': 'Maintain optimal app size and performance'
        })

    def print_analysis_report(self):
        """Print comprehensive analysis report"""
        print("\n" + "="*80)
        print("📊 HANSL DEPENDENCY SECURITY & SAFETY ANALYSIS REPORT")
        print("="*80)
        
        # Critical Issues
        if self.critical_issues:
            print(f"\n🚨 CRITICAL ISSUES ({len(self.critical_issues)}):")
            for issue in self.critical_issues:
                print(f"  ❌ {issue}")
        
        # High Issues
        if self.high_issues:
            print(f"\n⚠️ HIGH PRIORITY ISSUES ({len(self.high_issues)}):")
            for issue in self.high_issues:
                if isinstance(issue, dict):
                    print(f"  🔴 {issue.get('issue', 'Issue')}: {issue.get('description', '')}")
                    if 'recommendation' in issue:
                        print(f"     💡 {issue['recommendation']}")
                else:
                    print(f"  🔴 {issue}")
        
        # Medium Issues
        if self.medium_issues:
            print(f"\n⚡ MEDIUM PRIORITY ISSUES ({len(self.medium_issues)}):")
            for issue in self.medium_issues:
                if isinstance(issue, dict):
                    print(f"  🟡 {issue.get('issue', 'Issue')}: {issue.get('description', '')}")
                    if 'recommendation' in issue:
                        print(f"     💡 {issue['recommendation']}")
                else:
                    print(f"  🟡 {issue}")
        
        # Low Issues
        if self.low_issues:
            print(f"\n📝 LOW PRIORITY ISSUES ({len(self.low_issues)}):")
            for issue in self.low_issues:
                if isinstance(issue, dict):
                    print(f"  🟢 {issue.get('issue', 'Issue')}: {issue.get('description', '')}")
                    if 'recommendation' in issue:
                        print(f"     💡 {issue['recommendation']}")
                else:
                    print(f"  🟢 {issue}")
        
        # Recommendations
        if self.recommendations:
            print(f"\n✨ RECOMMENDATIONS ({len(self.recommendations)}):")
            for rec in self.recommendations:
                print(f"  💎 {rec['category']}: {rec['suggestion']}")
                print(f"     🎯 Benefit: {rec['benefit']}")
        
        # Summary
        total_issues = len(self.critical_issues) + len(self.high_issues) + len(self.medium_issues) + len(self.low_issues)
        print(f"\n📈 SUMMARY:")
        print(f"  Total Issues: {total_issues}")
        print(f"  Critical: {len(self.critical_issues)}")
        print(f"  High: {len(self.high_issues)}")
        print(f"  Medium: {len(self.medium_issues)}")
        print(f"  Low: {len(self.low_issues)}")
        print(f"  Recommendations: {len(self.recommendations)}")
        
        # Risk Score
        risk_score = (len(self.critical_issues) * 10) + (len(self.high_issues) * 5) + (len(self.medium_issues) * 2) + len(self.low_issues)
        risk_level = "LOW"
        if risk_score > 20:
            risk_level = "HIGH"
        elif risk_score > 10:
            risk_level = "MEDIUM"
            
        print(f"\n🎯 OVERALL RISK ASSESSMENT: {risk_level} (Score: {risk_score})")
        
        if risk_level == "HIGH":
            print("  🚨 Immediate attention required for critical and high-priority issues")
        elif risk_level == "MEDIUM":
            print("  ⚠️ Address high-priority issues and plan for medium-priority ones")
        else:
            print("  ✅ Dependencies are in good shape, monitor and maintain regularly")

    def analyze(self, pubspec_yaml_path: str, pubspec_lock_path: str):
        """Run complete dependency analysis"""
        print("🚀 Starting HANSL Dependency Analysis...")
        
        # Load configuration files
        pubspec_data = self.load_pubspec_yaml(pubspec_yaml_path)
        lock_packages = self.parse_pubspec_lock(pubspec_lock_path)
        
        if not pubspec_data:
            return
        
        dependencies = pubspec_data.get('dependencies', {})
        
        # Run all analyses
        self.analyze_security_vulnerabilities(dependencies, lock_packages)
        self.analyze_outdated_packages(lock_packages)
        self.analyze_dependency_conflicts(dependencies)
        self.analyze_unused_dependencies(pubspec_data)
        self.analyze_security_best_practices(pubspec_data)
        self.analyze_performance_implications(dependencies, lock_packages)
        self.analyze_maintenance_burden(dependencies)
        self.generate_recommendations(pubspec_data)
        
        # Generate report
        self.print_analysis_report()

if __name__ == "__main__":
    analyzer = DependencyAnalyzer()
    analyzer.analyze("pubspec.yaml", "pubspec.lock")