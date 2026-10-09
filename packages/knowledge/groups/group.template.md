---
id: example-group
name: Example Group
kind: mechanic
aliases: []
status: active
maturity: seed
created_at: YYYY-MM-DD
approval_status: approved
approved_by: producer
reviewed_revision: GIT_SHA
definition_hash: SHA256
last_review_receipt: system/maintenance/group-reviews/example-group-YYYYMMDD.json
coverage_matrix: system/maintenance/group-reviews/example-group-YYYYMMDD.coverage.json
candidate_review: system/maintenance/group-reviews/example-group-YYYYMMDD.json
candidate_members: []
review_when:
  - Group 定义、别名、分类或覆盖维度变化
  - 新建或实质修改的 Wiki 命中发现信号
  - Query 报告可能遗漏成员
---

# Example Group

## 定义

说明这个 Group 解决的稳定问题族，以及它与 Domain 的区别。

## 检索与共同阅读用例

至少列出一个具体用户问题、应补到的候选类型，以及它如何补充直接发现的缺口；说明一项不应扩读的反例。

候选命中不是已读正文；按当前 Query 需要选择核心页与补充页，不能以 Group 成员数量作为充分性证明。

## 纳入边界

## 排除边界

## 反例

## 覆盖维度

- 定义：
- 机制：

## 候选成员与边界记录

`candidate_members` 只记录当前仍需维护的非成员候选（`excluded` 或 `unresolved`）；逐项理由、发现信号与历史裁决以 `candidate_review` 指向的收据为准。候选不能被 Query 当作成员读取。

| 候选页面 | 当前裁决 | 原因摘要 | 重开条件 |
| --- | --- | --- | --- |

## 相关 Wiki 页面

<!-- generated:wiki-group-members:start -->
<!-- generated:wiki-group-members:end -->
