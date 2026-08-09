# BB Transaction CDC Source 超时修复计划

- [x] 根据 VVR 截图定位失败/取消集中在 transaction/card/settlement Source。
- [x] 对照当前 CDC 脚本确认三个主 Source 存在大范围读取。
- [x] 将 transaction Source 改为按昨天交易变更和昨天 settlement 命中交易下推过滤。
- [x] 将 card 和 settlement Source 改为跟随 changed tx 下推过滤。
- [x] 将 correlated `EXISTS + OR` 改为 `UNION + 等值 JOIN`。
- [x] 将 CDC 执行并行度和网络参数对齐 batch，减少 Source task 膨胀。
- [x] 执行静态检查确认三个主 Source 不再裸扫。
- [ ] 重新部署验证作业不再无异常失败。
