# 日历添加提醒工具

### 功能

* 添加提醒
* 提醒可重复, 可设置提前通知时间
* 删除提醒

### 示例
```objc
HSKEvent *event = [HSKEvent otherBillEventFor:title at:dateString before:timeComponents.firstObject];
[HSKEventStore addEvent:event];
```

