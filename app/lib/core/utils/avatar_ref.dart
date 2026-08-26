/// 头像引用判定工具。
///
/// 头像字段只允许三种「能被所有端访问」的值：
///   - emoji（如 `🐼`，涂鸦头像）
///   - http(s) URL（外部图 / MinIO 公开地址）
///   - `/uploads/<key>`（本服务对象存储；客户端按 API origin 拼接完整地址）
///
/// 旧版本客户端曾把本机图片路径（`C:\...`、`/data/user/0/...`、`file://...`）
/// 直接作为 avatarUrl 入库——该路径在其它设备上不存在，App 重启后还会因
/// 系统清理缓存目录而失效，群成员列表/账单参与人只能用昵称首字兜底渲染。
/// [isLocalAvatarRef] 用于识别这类脏数据（启动自愈 + 展示层回退）。
bool isLocalAvatarRef(String value) {
  if (value.isEmpty) return false;
  if (value.startsWith('http://') || value.startsWith('https://')) return false;
  if (value.startsWith('/uploads/')) return false;
  if (value.startsWith('file://')) return true;
  if (value.contains('\\')) return true;
  if (value.startsWith('/')) return true;
  return RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value);
}
