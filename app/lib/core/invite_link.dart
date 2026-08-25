/// 群组邀请链接解析
///
/// 邀请链接统一形如 `aafen://join/群码`（见 [AppConfig.inviteScheme]），
/// 但从聊天消息/扫码结果里粘贴进来的可能是五花八门的格式，这里做宽容解析：
///
/// - `aafen://join/FAN12345`（深链标准格式）
/// - `https://aafen.com/join/FAN12345`（H5 分享页）
/// - `https://aafen.com/join/FAN12345?from=share`（带参数）
/// - 直接粘贴裸群码 `FAN12345`
///
/// 识别失败返回 null，由调用方提示用户检查链接。
String? parseInviteCode(String? input) {
  var s = (input ?? '').trim().replaceAll(RegExp(r'\s+'), '');
  if (s.isEmpty) return null;

  // 1) 剥离 scheme（aafen://、https://、http:// 等）
  final scheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.\-]*://').firstMatch(s);
  if (scheme != null) {
    s = s.substring(scheme.end);
    // 2) 跳过 host/命名空间（aafen://join/CODE → join/CODE；https://x/join/CODE → join/CODE）
    final slash = s.indexOf('/');
    if (slash >= 0) s = s.substring(slash + 1);
  }

  // 3) 剥离常见 path 前缀
  final lower = s.toLowerCase();
  const prefixes = ['join/', 'invite/', 'invites/'];
  for (final p in prefixes) {
    if (lower.startsWith(p)) {
      s = s.substring(p.length);
      break;
    }
  }

  // 4) 只保留第一段：去掉查询/锚点/尾部斜杠
  s = s.split(RegExp(r'[?#/]')).first.trim();
  if (s.isEmpty) return null;

  // 5) 群码字符集：字母（大小写宽容）+ 数字，长度 1-12（与服务端 JoinGroupDto 一致）
  if (!RegExp(r'^[A-Za-z0-9]{1,12}$').hasMatch(s)) return null;
  return s;
}
