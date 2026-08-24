# Case Scope

## meta
- case_id: 20260824-flutter-sec-audit
- created: 2026-08-24T21:17:00+08:00
- operator: DocReviewer (Monster world)
- primary_skill: reverse-engineering
- lead_role: lead
- specialist_roles: []

## auth
- status: granted
- basis: own_system
- evidence_of_auth: 用户明确指定项目路径 D:\claude\work\cn_com_lange\word_app

## in_scope
- assets:
  - D:\claude\work\cn_com_lange\word_app\ (Flutter 项目完整目录)
  - D:\claude\work\cn_com_lange\word_app\lib\ (Dart 源代码)
  - D:\claude\work\cn_com_lange\word_app\android\ (Android 配置)
  - D:\claude\work\cn_com_lange\word_app\windows\ (Windows 配置)
  - D:\claude\work\cn_com_lange\word_app\pubspec.yaml (项目配置)
  - D:\claude\work\cn_com_lange\word_app\assets\ (资源文件)
- surfaces:
  - source_code
  - configuration
  - build_settings
  - resource_files
- activities:
  - code_audit
  - configuration_review
  - security_assessment
  - report_generation

## out_of_scope
- assets: []
- activities:
  - active_exploitation
  - network_scanning
  - dynamic_analysis
  - reverse_engineering_compiled_binary
  - penetration_testing

## network_profile
- mode: offline
- notes: 纯静态代码审计和配置审查，不涉及任何对外发包或动态分析

## deliverables
- report: true
- field_journal: false
- diagrams: false
- timeline: false

## constraints
- timebox: {}
- stealth: low
- data_handling: anonymize

## signoff
- ready_for_act: true
- checklist:
  - [x] auth.status = granted
  - [x] in_scope.assets non-empty
  - [x] network_profile.mode = offline
  - [x] out_of_scope reviewed
