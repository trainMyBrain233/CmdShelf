# CmdShelf MVP

CmdShelf 是一个 macOS 13+ 的本地优先“命令 & SOP 管理器”最小 MVP：
- 全局热键唤起 Main Window（默认 `Cmd + D`）
- 搜索 Commands / SOPs
- 一键复制命令，并记录复制次数与最近使用时间
- SOP Markdown 渲染，并提取 code blocks 一键复制
- Inbox 从剪贴板收集内容，再归档为 Command / SOP
- 数据落地 MySQL（连接池 + 启动自动迁移）

## 技术栈
- Swift 5.9+ / SwiftUI App
- macOS 13+
- MySQL（`vapor/mysql-kit`）
- `KeyboardShortcuts`
- `MarkdownUI`
- `swift-markdown`

## 工程结构
- `Package.swift`
- `Sources/CmdShelf/...`（按 App / Models / Database / Repositories / Services / UI 分层）

可直接在 Xcode 打开 `Package.swift` 运行。

## 快速启动

### 1) 启动 MySQL（Docker Compose 示例）
在任意目录创建 `docker-compose.yml`：

```yaml
services:
  mysql:
    image: mysql:8.4
    container_name: cmdshelf-mysql
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: rootpass
      MYSQL_DATABASE: cmdshelf
      MYSQL_USER: cmdshelf
      MYSQL_PASSWORD: cmdshelfpass
    ports:
      - "3306:3306"
    command: ["--default-authentication-plugin=mysql_native_password"]
    volumes:
      - mysql_data:/var/lib/mysql

volumes:
  mysql_data:
```

启动：

```bash
docker compose up -d
```

### 2) 创建数据库与授权（本机 MySQL 示例 SQL）
如果你使用已有 MySQL 实例，可执行：

```sql
CREATE DATABASE IF NOT EXISTS cmdshelf CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS 'cmdshelf'@'localhost' IDENTIFIED BY 'cmdshelfpass';
GRANT ALL PRIVILEGES ON cmdshelf.* TO 'cmdshelf'@'localhost';
FLUSH PRIVILEGES;
```

> 应用启动时也会尝试自动创建数据库与表。若权限不足，会显示错误并在 Settings 中给出建议。

### 3) 运行应用
连接参数通过进程环境变量配置。默认主机为 `localhost`、端口为 `3306`、用户为 `root`、数据库为 `cmdshelf`；密码默认为空，不随源码发布。

使用上面的演示数据库账号，可在终端设置后运行：

```bash
export CMDSHELF_MYSQL_HOST=localhost
export CMDSHELF_MYSQL_PORT=3306
export CMDSHELF_MYSQL_USER=cmdshelf
export CMDSHELF_MYSQL_DATABASE=cmdshelf
export CMDSHELF_MYSQL_PASSWORD='cmdshelfpass' # 仅对应上文的本地演示账号
swift run CmdShelf
```

在 Xcode 中运行时，在 Scheme → Run → Arguments → Environment Variables 设置同样的变量。运行打包应用时，从设置好变量的终端直接执行 `dist/CmdShelf.app/Contents/MacOS/CmdShelf`。Finder 双击启动不会自动继承终端变量。示例密码只用于本地演示，请勿用于真实服务。

- 在 Xcode 打开 `Package.swift`
- 选择 `CmdShelf` 运行
- 首次进入 `Settings` 可查看当前环境变量配置的连接信息（只读）
- 点击 `Retry Connection` 检查当前连接状态

## 自动迁移说明
应用启动后执行幂等迁移：
- `CREATE DATABASE IF NOT EXISTS cmdshelf`
- `CREATE TABLE IF NOT EXISTS`：
  - `commands`
  - `sops`
  - `inbox_items`
  - `usage_events`
- 索引通过 `information_schema` 检查后按需创建（避免重复）

## 默认快捷键
- 打开 Main Window：`Cmd + D`
- 在 Palette 中：
  - `Enter`：执行主操作（复制命令 / 打开 SOP 详情）
  - `Cmd + Enter`：在主窗口打开详情
  - `Esc`：关闭面板

可在 `Settings` 使用 Hotkey Recorder 修改全局快捷键。

## 已实现（MVP）
- MenuBarExtra 菜单：
  - Open Main Window
  - Open Command Palette
  - Quick Copy: Most Used (Top 5)
  - Inbox
  - Settings
  - Quit
  - MySQL 连接状态显示（Connected / Disconnected）
- 主窗口三栏：Groups / List(Tabs) / Detail
- Commands CRUD（MySQL）
- SOP CRUD（MySQL）
- 全局搜索（LIKE）+ 混合排序（Pinned / CopyCount / LastUsed / Title）
- 复制命令后原子更新：`copy_count + 1`, `last_copied_at`, `usage_events(copy)`
- SOP code blocks 提取与复制，复制后记一次 SOP 使用
- Inbox 抓取剪贴板并检测类型（cmd/sop/text），支持归档
- Settings 显示只读连接配置并支持连接重试
- 统一 `AppError` 错误包装与 UI Alert
- 断连提示 `Database disconnected`，主要写操作禁用
- 最小种子数据（首次空库自动写入 2 条 command + 1 条 sop）

## 未实现（MVP 边界）
- 云同步 / 账户登录 / 多端同步
- 前台应用自动粘贴注入（`FrontmostAppService` 仅占位）
- 高级全文索引（目前仅 LIKE）
- 复杂权限模型 / 团队协作
- 自动备份与导入导出

## 安全说明
- MySQL 密码从 `CMDSHELF_MYSQL_PASSWORD` 环境变量读取，不内置在源码中。
- 当前版本不使用 Keychain，也不从 UserDefaults 读取密码；设置界面仅展示只读连接信息。
- `.build/`、`dist/` 与本地 `.env` 文件不纳入版本控制；应用不会自动加载 `.env`。

## 自检清单
- `swift build` 通过
- 启动后自动迁移，无需手动建表
- 可新增命令与 SOP
- Palette 可搜索并复制命令，复制计数增长
- SOP code blocks 可复制并写 usage 事件
- Inbox 可抓取剪贴板并归档

## 已打包应用与本地配置

仓库提供 `dist/CmdShelf-macos-arm64.zip`，为 Apple Silicon（arm64）Mac 的 Release 构建，使用 ad-hoc 签名，未经过 Apple 公证。应用包从当前源码重新构建，不含原本写死的数据库密码。首次运行可能需要按 macOS 的安全提示确认。

`.env.example` 保留原本的本机数据库连接参数（localhost:3306、root、cmdshelf），密码位置为占位符。复制后填写你自己的密码：

```bash
cp .env.example .env
# 编辑 .env，填写本机数据库密码；该文件被 Git 忽略。
set -a
source .env
set +a
unzip dist/CmdShelf-macos-arm64.zip -d dist
./dist/CmdShelf.app/Contents/MacOS/CmdShelf
```

编译缓存 `.build/`、Xcode 个人窗口状态和 `.DS_Store` 不上传。原始应用包包含旧的内置数据库配置，因此以重新构建的版本替代。
