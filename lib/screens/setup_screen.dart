import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../generated/window_api.g.dart';
import '../main.dart';
import '../pass_service.dart';
import '../setup_state.dart';

final _windowApi = WindowApi();

class SetupScreen extends ConsumerWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(setupProvider);
    final c = Theme.of(context).extension<ProtonifyColors>()!;

    return Scaffold(
      body: Column(
        children: [
          _DragBar(c: c),
          Expanded(
            child: Center(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: switch (status) {
                  SetupStatus.checking => _CheckingView(key: const ValueKey('checking')),
                  SetupStatus.cliNotFound => _CliNotFoundView(key: const ValueKey('notfound')),
                  SetupStatus.notLoggedIn => _NotLoggedInView(key: const ValueKey('notlogged')),
                  SetupStatus.ready => const SizedBox.shrink(),
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DragBar extends StatelessWidget {
  final ProtonifyColors c;
  const _DragBar({required this.c});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onPanStart: (_) => _windowApi.startDrag(),
      child: Container(
        height: 52,
        color: c.surface,
        alignment: Alignment.center,
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          'Protonify',
          style: TextStyle(
            color: c.onSurface,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

// ---------- Checking / Loading ----------

class _CheckingView extends StatelessWidget {
  const _CheckingView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<ProtonifyColors>()!;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32,
          height: 32,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            color: c.accent,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Checking setup...',
          style: TextStyle(color: c.subtle, fontSize: 13),
        ),
      ],
    );
  }
}

// ---------- CLI Not Found ----------

class _CliNotFoundView extends ConsumerWidget {
  const _CliNotFoundView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<ProtonifyColors>()!;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.terminal_rounded, size: 32, color: c.accent),
            ),
            const SizedBox(height: 24),
            Text(
              'Proton Pass CLI Required',
              style: TextStyle(
                color: c.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Protonify needs the Proton Pass CLI to manage your passwords.\nInstall it, then come back and retry.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.subtle, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 28),
            _SetupCard(
              c: c,
              step: '1',
              title: 'Install Proton Pass CLI',
              subtitle: 'Run this command in Terminal:',
              command: 'brew install protonpass-cli',
            ),
            const SizedBox(height: 12),
            _SetupCard(
              c: c,
              step: '2',
              title: 'Log in to your account',
              subtitle: 'Authenticate with your Proton credentials:',
              command: 'pass-cli auth login',
            ),
            const SizedBox(height: 28),
            _RetryButton(ref: ref, c: c),
          ],
        ),
      ),
    );
  }
}

// ---------- Not Logged In ----------

class _NotLoggedInView extends ConsumerWidget {
  const _NotLoggedInView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = Theme.of(context).extension<ProtonifyColors>()!;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: c.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.lock_open_rounded, size: 32, color: c.accent),
            ),
            const SizedBox(height: 24),
            Text(
              'Sign In Required',
              style: TextStyle(
                color: c.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'The Proton Pass CLI is installed, but you need to sign in\nto your Proton account before Protonify can access your vaults.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.subtle, fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 28),
            _SetupCard(
              c: c,
              step: '1',
              title: 'Log in via Terminal',
              subtitle: 'Run this command and follow the prompts:',
              command: 'pass-cli auth login',
            ),
            const SizedBox(height: 28),
            _RetryButton(ref: ref, c: c),
          ],
        ),
      ),
    );
  }
}

// ---------- Shared Widgets ----------

class _SetupCard extends StatefulWidget {
  final ProtonifyColors c;
  final String step;
  final String title;
  final String subtitle;
  final String command;

  const _SetupCard({
    required this.c,
    required this.step,
    required this.title,
    required this.subtitle,
    required this.command,
  });

  @override
  State<_SetupCard> createState() => _SetupCardState();
}

class _SetupCardState extends State<_SetupCard> {
  bool _copied = false;
  Timer? _timer;

  void _copy() {
    Clipboard.setData(ClipboardData(text: widget.command));
    setState(() => _copied = true);
    _timer?.cancel();
    _timer = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.surfaceVariant, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: c.accent,
                  borderRadius: BorderRadius.circular(6),
                ),
                alignment: Alignment.center,
                child: Text(
                  widget.step,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                widget.title,
                style: TextStyle(
                  color: c.onSurface,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            widget.subtitle,
            style: TextStyle(color: c.subtle, fontSize: 12),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: _copy,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: c.surfaceVariant.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.command,
                        style: TextStyle(
                          color: c.accent,
                          fontSize: 13,
                          fontFamily: 'SF Mono, Menlo, monospace',
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _copied
                          ? Icon(Icons.check_rounded, key: const ValueKey('check'), size: 16, color: Colors.green)
                          : Icon(Icons.copy_rounded, key: const ValueKey('copy'), size: 16, color: c.subtle),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RetryButton extends StatefulWidget {
  final WidgetRef ref;
  final ProtonifyColors c;
  const _RetryButton({required this.ref, required this.c});

  @override
  State<_RetryButton> createState() => _RetryButtonState();
}

class _RetryButtonState extends State<_RetryButton> {
  bool _loading = false;

  Future<void> _retry() async {
    setState(() => _loading = true);
    await widget.ref.read(setupProvider.notifier).check();
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    return SizedBox(
      width: 200,
      height: 40,
      child: ElevatedButton(
        onPressed: _loading ? null : _retry,
        style: ElevatedButton.styleFrom(
          backgroundColor: c.accent,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          elevation: 0,
        ),
        child: _loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Retry',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}
