# martin-dev-log

个人工作笔记仓库，记录支付/金融业务分析、数据清洗脚本、SQL 查询等。

## 项目结构

| 目录/文件 | 说明 |
|---|---|
| `scheme-fee.md` | Scheme Fee（卡组/品牌手续费）方案分析 |
| `RS-cash.md` | RS 毛利返现计算逻辑 |
| `fb-channel-fees/` | FB 渠道费率（bb, l2c, ql, sl）|
| `ocdd/` | OCDD 年度评审 SQL |
| `config-links/` | 配置相关链接/SQL |
| `data-cleaning/` | 数据清洗脚本 |
| `qbit-card-cost-cleaning/` | 量子卡成本清洗（多个子目录） |
| `design-docs/` | 开发方案文档（每个迭代/功能一个文件）|
| `changelogs/` | 发布日志 |
| `plans/` | 执行计划 |

## 协作规范

- 文档使用 Markdown 书写
- SQL 脚本建议附带说明注释
- 有分析结论或决策的文档，建议在开头加一段摘要
- 新想法可以先建 `.md` 草稿，完善后再提交

## 迭代流程

1. **开发方案** → 在 `design-docs/` 下编写方案文档，评审通过后进入开发
2. **执行开发** → 可使用 `plans/` 记录执行步骤和进度
3. **发布日志** → 上线后在 `changelogs/` 记录变更内容
4. **提交** → `git add` + `git commit` + `git push`

## 常用操作

- 书写新文档：在根目录或对应子目录下创建 `.md` 文件
- 查看已有文档：`/Users/martinjiang/Desktop/martin-dev-log/`
- Git 管理：commit → push 到 GitHub
