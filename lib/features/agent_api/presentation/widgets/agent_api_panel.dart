import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/config/service_locator.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/services/cache_service.dart';
import '../../data/services/agent_api_service.dart';

/// Settings panel for the local Agent API: enable/disable, port, and the
/// credentials external agents need (bearer token + discovery file path).
class AgentApiPanel extends StatefulWidget {
  const AgentApiPanel({super.key});

  @override
  State<AgentApiPanel> createState() => _AgentApiPanelState();
}

class _AgentApiPanelState extends State<AgentApiPanel> {
  final AgentApiService _service = locator<AgentApiService>();
  final TextEditingController _portController = TextEditingController();

  bool _loaded = false;
  bool _enabled = false;
  bool _busy = false;
  String? _discoveryPath;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _portController.dispose();
    super.dispose();
  }

  Future<void> _init() async {
    _enabled = await CacheService.loadAgentApiEnabled();
    final int port = await CacheService.loadAgentApiPort();
    _portController.text = port.toString();
    try {
      _discoveryPath = await _service.discoveryFilePath();
    } catch (_) {
      // path_provider unavailable — credentials section just hides the path.
      _discoveryPath = null;
    }
    if (mounted) setState(() => _loaded = true);
  }

  Future<void> _onToggle(bool value) async {
    setState(() => _busy = true);
    await CacheService.saveAgentApiEnabled(value);
    if (value) {
      await _service.start();
    } else {
      await _service.stop();
    }
    if (mounted) {
      setState(() {
        _enabled = value;
        _busy = false;
      });
    }
  }

  Future<void> _onPortSubmitted() async {
    final int? parsed = int.tryParse(_portController.text.trim());
    if (parsed == null || parsed < 0 || parsed > 65535) return;
    await CacheService.saveAgentApiPort(parsed);
    if (_service.isRunning) {
      await _service.restart();
      if (mounted) setState(() {});
    }
  }

  Future<void> _copy(String label, String? value) async {
    if (value == null || value.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: value));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool running = _service.isRunning;
    final int? port = running ? _service.port : null;
    final String? token = _service.token;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: <Widget>[
        _sectionLabel('Agent API'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: panelRaised,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _enabled ? lightPink.withValues(alpha: 0.4) : hairline,
            ),
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Text(
                      'Agent API',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      running
                          ? 'Listening on http://127.0.0.1:$port'
                          : 'Stopped',
                      style: TextStyle(
                        color: running ? lightPink : textMuted,
                        fontSize: 12,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Lets external AI agents (Claude Code, scripts) read saved '
                      'prompts and write captions over localhost, using their own '
                      'vision. Bound to 127.0.0.1 with a bearer token.',
                      style: TextStyle(color: textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              _PinkSwitch(
                value: _enabled,
                onChanged: _busy || !_loaded ? null : _onToggle,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionLabel('Connection'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: panelDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: hairline),
          ),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  const Icon(Icons.settings_ethernet, size: 18, color: lightPink),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Port',
                      style: TextStyle(color: textPrimary, fontSize: 13),
                    ),
                  ),
                  SizedBox(
                    width: 96,
                    child: TextField(
                      controller: _portController,
                      enabled: _loaded,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.right,
                      onSubmitted: (_) => _onPortSubmitted(),
                      decoration: InputDecoration(
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 9,
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(7),
                          borderSide: const BorderSide(color: hairline),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(7),
                          borderSide: BorderSide(
                            color: lightPink.withValues(alpha: 0.6),
                          ),
                        ),
                        hintText: '8765',
                        hintStyle: const TextStyle(color: textMuted),
                      ),
                      style: const TextStyle(color: textPrimary, fontSize: 13),
                    ),
                  ),
                ],
              ),
              if (_discoveryPath != null) ...<Widget>[
                const Divider(color: hairline, height: 28),
                _copyableRow(
                  icon: Icons.description_outlined,
                  label: 'Discovery file',
                  value: _discoveryPath,
                  onCopy: () => _copy('Discovery file path', _discoveryPath),
                ),
              ],
              if (token != null) ...<Widget>[
                const Divider(color: hairline, height: 28),
                _copyableRow(
                  icon: Icons.key_outlined,
                  label: 'Token',
                  value: token,
                  onCopy: () => _copy('Token', token),
                  monospace: true,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        _sectionLabel('Usage'),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: panelDark,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: hairline),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Agents discover the port and token by reading the discovery '
                'file above. Quick test:',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
              SizedBox(height: 10),
              Text(
                'curl http://127.0.0.1:<port>/api/health\n'
                    '\n'
                    'curl http://127.0.0.1:<port>/api/prompts \\\n'
                    '  -H "Authorization: Bearer <token>"\n'
                    '\n'
                    'curl -X POST http://127.0.0.1:<port>/api/captions \\\n'
                    '  -H "Authorization: Bearer <token>" \\\n'
                    '  -H "Content-Type: application/json" \\\n'
                    '  -d \'{"folder": "/path/to/images", '
                    '"filename": "cat.jpg", "text": "a cat"}\'',
                style: TextStyle(
                  color: textPrimary,
                  fontSize: 11.5,
                  fontFamily: 'Inter',
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sectionLabel(String text) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      fontFamily: 'Orbitron',
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: lightPink,
      letterSpacing: 1.1,
    ),
  );

  Widget _copyableRow({
    required IconData icon,
    required String label,
    required String? value,
    required VoidCallback onCopy,
    bool monospace = false,
  }) {
    return Row(
      children: <Widget>[
        Icon(icon, size: 18, color: lightPink),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: const TextStyle(color: textPrimary, fontSize: 13),
              ),
              const SizedBox(height: 2),
              Text(
                value ?? '',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: textSecondary,
                  fontSize: 11.5,
                  letterSpacing: monospace ? 0.5 : 0,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.copy, size: 16),
          tooltip: 'Copy',
          onPressed: value == null || value.isEmpty ? null : onCopy,
        ),
      ],
    );
  }
}

class _PinkSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;

  const _PinkSwitch({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Switch(
      value: value,
      onChanged: onChanged,
      activeThumbColor: lightPink,
      activeTrackColor: lightPink.withValues(alpha: 0.35),
      inactiveThumbColor: textSecondary,
      inactiveTrackColor: hairline,
      trackOutlineColor: WidgetStateProperty.all<Color>(Colors.transparent),
    );
  }
}
