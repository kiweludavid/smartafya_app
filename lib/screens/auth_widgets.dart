import 'package:flutter/material.dart';

import 'app_palette.dart';

class AuthPageScaffold extends StatefulWidget {
  final String subtitle;
  final Widget child;

  const AuthPageScaffold({
    super.key,
    required this.subtitle,
    required this.child,
  });

  @override
  State<AuthPageScaffold> createState() => _AuthPageScaffoldState();
}

class _AuthPageScaffoldState extends State<AuthPageScaffold> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: _visible ? 1 : 0,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOut,
      child: Scaffold(
        backgroundColor: SmartAfyaPalette.scaffoldBg,
        body: SafeArea(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    AuthHeader(subtitle: widget.subtitle),
                    const SizedBox(height: 28),
                    widget.child,
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AuthHeader extends StatelessWidget {
  final String subtitle;

  const AuthHeader({super.key, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 116,
          height: 116,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: SmartAfyaPalette.primaryBlue.withAlpha(45),
                blurRadius: 22,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Image.asset(
              'assets/images/smart_afya_logo.png',
              fit: BoxFit.contain,
              errorBuilder: (_, _, _) => const Icon(
                Icons.self_improvement_rounded,
                color: SmartAfyaPalette.primaryGreen,
                size: 46,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Smart Afya',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
                color: SmartAfyaPalette.deepText,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                fontSize: 15,
                color: SmartAfyaPalette.mutedText,
                height: 1.45,
              ),
        ),
      ],
    );
  }
}

class AuthCard extends StatelessWidget {
  final Widget child;

  const AuthCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: Color(0xFFE4EEF7)),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [
            BoxShadow(
              color: Color(0x1A2A5F8A),
              blurRadius: 28,
              offset: Offset(0, 14),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: child,
      ),
    );
  }
}

class PrimaryActionButton extends StatefulWidget {
  final String label;
  final bool isLoading;
  final VoidCallback onPressed;

  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  State<PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<PrimaryActionButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => _setPressed(true),
      onPointerUp: (_) => _setPressed(false),
      onPointerCancel: (_) => _setPressed(false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: widget.isLoading ? null : widget.onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: SmartAfyaPalette.primaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shadowColor: SmartAfyaPalette.primaryBlue.withAlpha(70),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: widget.isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    widget.label,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class BottomAuthLink extends StatelessWidget {
  final String prefix;
  final String action;
  final VoidCallback onTap;

  const BottomAuthLink({
    super.key,
    required this.prefix,
    required this.action,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          prefix,
          style: const TextStyle(
            color: SmartAfyaPalette.mutedText,
            fontSize: 14,
          ),
        ),
        GestureDetector(
          onTap: onTap,
          child: Text(
            action,
            style: const TextStyle(
              color: SmartAfyaPalette.primaryGreen,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }
}

class SmartAfyaInputField extends StatefulWidget {
  final TextEditingController controller;
  final String hint;
  final String? helperText;
  final IconData icon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final Widget? suffix;
  final String? Function(String?)? validator;

  const SmartAfyaInputField({
    super.key,
    required this.controller,
    required this.hint,
    required this.icon,
    this.helperText,
    this.keyboardType,
    this.textInputAction,
    this.obscureText = false,
    this.suffix,
    this.validator,
  });

  @override
  State<SmartAfyaInputField> createState() => _SmartAfyaInputFieldState();
}

class _SmartAfyaInputFieldState extends State<SmartAfyaInputField> {
  late final FocusNode _focusNode;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!mounted) return;
      setState(() => _isFocused = _focusNode.hasFocus);
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  static const _idleBorderColor = Color(0xFFB6CFE8);
  static const _focusBorderColor = Color(0xFF2563EB);
  static const _errorBorderColor = Color(0xFFE26060);
  static const _glassFill = Color(0xFFF6FAFD);

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: SmartAfyaPalette.primaryBlue.withAlpha(18),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
          if (_isFocused)
            BoxShadow(
              color: _focusBorderColor.withAlpha(60),
              blurRadius: 22,
              spreadRadius: 1,
              offset: const Offset(0, 6),
            ),
        ],
      ),
      child: TextFormField(
        focusNode: _focusNode,
        controller: widget.controller,
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        obscureText: widget.obscureText,
        decoration: InputDecoration(
          hintText: widget.hint,
          helperText: widget.helperText,
          helperStyle: const TextStyle(
            color: SmartAfyaPalette.mutedText,
            fontSize: 12,
            height: 1.25,
          ),
          hintStyle: const TextStyle(
            color: Color(0xFF6B8196),
            fontWeight: FontWeight.w500,
          ),
          filled: true,
          fillColor: _glassFill,
          prefixIcon: Icon(widget.icon, color: SmartAfyaPalette.primaryBlue),
          suffixIcon: widget.suffix,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _idleBorderColor, width: 1.4),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _idleBorderColor, width: 1.4),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _focusBorderColor, width: 2.0),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _errorBorderColor, width: 1.4),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: _errorBorderColor, width: 2.0),
          ),
        ),
        validator: widget.validator,
      ),
    );
  }
}
