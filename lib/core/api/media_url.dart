/// 把服务端返回的媒体地址处理成当前能访问的地址。
///
/// 后端的 `avatarUrl` 是绝对地址，但主机名取的是它自己收到请求时的 Host，
/// 从手机访问时经常是 `http://localhost:8080/...` —— 手机上的 localhost 是手机自己，
/// 加载不到。这里统一换成登录页填的 baseUrl 的主机。
String? resolveMediaUrl(String? url, String baseUrl) {
  final raw = (url ?? '').trim();
  if (raw.isEmpty) return null;

  final base = Uri.tryParse(baseUrl.trim());
  if (base == null || !base.hasScheme || base.host.isEmpty) return raw;

  // 相对路径：直接拼在 baseUrl 后面
  if (raw.startsWith('/')) return '${base.scheme}://${base.authority}$raw';

  final target = Uri.tryParse(raw);
  if (target == null || !target.hasScheme) return raw;

  final targetIsLoopback = _isLoopback(target.host);
  final baseIsLoopback = _isLoopback(base.host);

  // 服务端给的是 localhost，但我们连的是局域网 IP → 换成 baseUrl 的主机
  if (targetIsLoopback && !baseIsLoopback) {
    final query = target.hasQuery ? '?${target.query}' : '';
    return '${base.scheme}://${base.authority}${target.path}$query';
  }

  return raw;
}

bool _isLoopback(String host) =>
    host == 'localhost' || host == '127.0.0.1' || host == '0.0.0.0' || host == '[::1]';
