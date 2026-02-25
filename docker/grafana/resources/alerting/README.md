# 告警规则

## 修改错误率阈值

编辑 `error_rate_rule.json`，找到 `"params": [5]`，将 `5` 改为目标值（如 `10` 表示错误率 10%，即成功率低于 90%）。

修改后需重新部署或执行 bootstrap 使配置生效。

## 钉钉告警模板

钉钉通知模板位于 `templates/` 目录，与 dashboards、datasources 一样通过 `bootstrap.sh` 的 HTTP API 应用：

- `templates/dingtalk-title.json`：钉钉告警标题模板
- `templates/dingtalk-message.json`：钉钉告警消息内容模板

修改后需重新执行 bootstrap 使配置生效。
