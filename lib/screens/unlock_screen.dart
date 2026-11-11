import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../main.dart';
import '../pass_service.dart';
import '../setup_state.dart';

class UnlockScreen extends ConsumerStatefulWidget {
  const UnlockScreen({super.key});

  @override
  ConsumerState<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends ConsumerState<UnlockScreen> {
  final _code = TextEditingController();
  final _svc = PassService();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _unlock() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter your lock code');
      return;
    }
    setState(() { _submitting = true; _error = null; });
    try {
      await _svc.unlockSession(code);
      if (mounted) ref.read(setupProvider.notifier).check();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Exception: ', '');
          _submitting = false;
          _code.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ProtonifyColors>()!;
    return Scaffold(
      backgroundColor: c.background,
      body: Center(
        child: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 56, height: 56,
                margin: const EdgeInsets.only(bottom: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.lock_outline, size: 26, color: c.accent),
              ),
              Text('Protonify is locked',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: c.onSurface)),
              const SizedBox(height: 6),
              Text('Enter your pass-cli lock code to continue.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: c.subtle)),
              const SizedBox(height: 20),
              TextField(
                controller: _code,
                autofocus: true,
                obscureText: true,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                onSubmitted: (_) => _submitting ? null : _unlock(),
                style: TextStyle(
                    fontSize: 20,
                    letterSpacing: 6,
                    fontFamily: 'Menlo',
                    color: c.onSurface),
                decoration: InputDecoration(
                  hintText: '••••••',
                  hintStyle: TextStyle(
                      fontSize: 20, letterSpacing: 6, color: c.subtle),
                  filled: true,
                  fillColor: c.surfaceVariant,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide(
                          color: c.accent.withValues(alpha: 0.6))),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 12, color: Color(0xFFFF375F))),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _submitting ? null : _unlock,
                style: FilledButton.styleFrom(
                  backgroundColor: c.accent,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: Text(_submitting ? 'Unlocking…' : 'Unlock'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
