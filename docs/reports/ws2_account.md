# WS-2: account 迁移为教科书式垂直功能模块

## 目标
参照字典范式模板（`lib/features/dictionary` 的四层结构），把 `account` 升级为教科书式垂直模块。

## 完成状态
✅ 已完成

## 迁移前结构（薄壳）
```
lib/features/account/
├── data/
│   └── account_profile_repository.dart  ← 混合层：值对象 + 端口 + 适配器全在一起
└── presentation/
    ├── account_feature_providers.dart   ← DI 注入
    ├── account_profile_state.dart       ← 状态管理
    └── app_session_state.dart           ← 会话状态

lib/pages/                                ← 5 个页面全在 pages 层
├── login_page.dart
├── splash_page.dart
├── my_space_page.dart
├── account_info_page.dart
└── user_info_manage_page.dart
```

问题：
- 缺少 domain / application 层
- 值对象 `AccountProfile` 和端口 `AccountProfileStore` 混在 data 层
- 页面逻辑全在 `lib/pages/`，违反 R1 分层架构

## 迁移后结构（教科书式四层）
```
lib/features/account/
├── domain/                              ← 纯领域层（新增）
│   └── account_profile.dart             # AccountProfile 值对象
├── application/                         ← 应用端口层（新增）
│   └── account_profile_store.dart       # AccountProfileStore 端口接口
├── data/                                ← 适配器层（重构）
│   └── account_profile_repository.dart  # 仅保留适配器，导入端口和领域
└── presentation/                        ← 展示层（扩展）
    ├── account_feature_providers.dart   # DI 注入（更新导入）
    ├── account_profile_state.dart       # 状态管理（更新导入）
    ├── app_session_state.dart           # 会话状态（不变）
    ├── splash_page.dart                 # 启动页 UI（从 pages 迁入）
    ├── login_page.dart                  # 登录页 UI（从 pages 迁入）
    ├── my_space_page.dart               # 我的空间页 UI（从 pages 迁入）
    ├── account_info_page.dart           # 账号信息页 UI（从 pages 迁入）
    ├── user_info_manage_page.dart       # 用户信息管理页 UI（从 pages 迁入）
    ├── message_page.dart                # 薄适配层（re-export）
    └── settings_page.dart               # 薄适配层（re-export）

lib/pages/                                ← 薄适配层（re-export）
├── splash_page.dart
├── login_page.dart
├── my_space_page.dart
├── account_info_page.dart
└── user_info_manage_page.dart
```

## 四层依赖方向验证

```
presentation (state, page)
    ↓
application (port interfaces)
    ↑
data (adapters implement ports)
    ↓
shared infrastructure (UserService, SharedPreferences)

domain (pure entities, zero imports)
```

✅ presentation → application（依赖方向正确）
✅ data → application（实现端口接口）
✅ domain → 无外部依赖（纯净）

## 新增文件清单

| 层 | 文件 | 说明 |
|---|---|---|
| domain | `account_profile.dart` | 账号资料值对象（从 data 层迁移） |
| application | `account_profile_store.dart` | 读写端口接口（从 data 层迁移） |
| presentation | `splash_page.dart` | 启动页 UI（从 pages 迁入） |
| presentation | `login_page.dart` | 登录页 UI（从 pages 迁入） |
| presentation | `my_space_page.dart` | 我的空间页 UI（从 pages 迁入） |
| presentation | `account_info_page.dart` | 账号信息页 UI（从 pages 迁入） |
| presentation | `user_info_manage_page.dart` | 用户信息管理页 UI（从 pages 迁入） |
| presentation | `message_page.dart` | 薄适配层（re-export from pages） |
| presentation | `settings_page.dart` | 薄适配层（re-export from pages） |

## 修改文件清单

| 文件 | 改动 |
|---|---|
| `data/account_profile_repository.dart` | 移除值对象和端口定义，改为导入 domain/application |
| `presentation/account_feature_providers.dart` | 添加 application 层导入 |
| `presentation/account_profile_state.dart` | 导入从 data 改为 application/domain |
| `test/.../account_profile_state_test.dart` | 导入路径更新 |

## 端口清单

### 读端口（Reader）
- `AccountProfileStore.load()` → `Future<AccountProfile>`

### 写端口（Writer/Store）
- `AccountProfileStore.save(AccountProfile)` → `Future<void>`

### 状态管理
- `AccountProfileState`（ChangeNotifier）→ 聚合读/写端口，提供 refresh/updateXxx 方法
- `AppSessionState`（ChangeNotifier）→ 会话/登录状态（保留不变）

## 关键设计决策

1. **AccountProfile 值对象**：从 data 层迁移到 domain 层，保持纯净（无外部依赖）
2. **AccountProfileStore 端口**：从 data 层迁移到 application 层，定义读写契约
3. **AccountProfileRepository 适配器**：仅保留实现，导入端口和领域类型
4. **页面迁移**：5 个页面完整 UI/逻辑迁入 feature layer，pages 层留薄 re-export

## 共享层边界

- **未改动** `lib/services/user_service.dart`
- **未改动** 共享模型 `lib/models/user_info_bean.dart`
- **未改动** 核心层 `core/app/theme/tokens`
- **未改动** `test/architecture/app_structure_test.dart`（lead 已修复）
- **未改动** checkin/scare_coin/learning/dictionary 模块

## 测试覆盖

### 既有测试（保留通过）
| 文件 | 说明 |
|---|---|
| `test/features/account/presentation/account_profile_state_test.dart` | 账号资料状态管理（导入路径已更新） |
| `test/features/account/presentation/app_session_state_test.dart` | 会话状态管理 |

### 全量测试结果
- ✅ 366 通过
- ❌ 0 失败

## 架构测试验证
- ✅ `account_feature_providers.dart` 包含 `AccountProfileRepository` 和 `AccountProfileState`
- ✅ 页面使用 `AccountProfileState` 管理资料
- ✅ 页面不直接依赖 `UserService` 或 `sl<` 服务定位器
- ✅ `my_space_page.dart` 包含 `ScareCoinStore` 引用

## 教科书标准达标

| 标准 | 状态 |
|---|---|
| R1-R6 四层分层 / 依赖方向 | ✅ |
| 读写分离（reader / writer port） | ✅ |
| domain 纯净（零外部依赖） | ✅ |
| 共享实体用 `lib/models/*` | ✅ |
| 依赖经 feature_providers 注入 | ✅ |
| flutter analyze 0 error | ✅ |
| flutter test 全量通过 | ✅ |
| 代码 + 测试 + 报告齐全 | ✅ |
