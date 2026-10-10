import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CambiarContrasenaDialog extends StatefulWidget {
  const CambiarContrasenaDialog({super.key});

  @override
  State<CambiarContrasenaDialog> createState() => _CambiarContrasenaDialogState();
}

class _CambiarContrasenaDialogState extends State<CambiarContrasenaDialog> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  bool _showCurrent = false;
  bool _showNew = false;
  bool _showConfirm = false;
  bool _cargando = false;
  String? _errorMsg;
  String? _successMsg;

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _cambiarContrasena() async {
    // Validaciones
    if (_currentCtrl.text.isEmpty) {
      setState(() => _errorMsg = 'Ingresa tu contraseña actual');
      return;
    }
    if (_newCtrl.text.isEmpty) {
      setState(() => _errorMsg = 'Ingresa una nueva contraseña');
      return;
    }
    if (_confirmCtrl.text.isEmpty) {
      setState(() => _errorMsg = 'Confirma tu nueva contraseña');
      return;
    }
    if (_newCtrl.text != _confirmCtrl.text) {
      setState(() => _errorMsg = 'Las nuevas contraseñas no coinciden');
      return;
    }
    if (_newCtrl.text == _currentCtrl.text) {
      setState(() => _errorMsg = 'La nueva contraseña debe ser diferente');
      return;
    }
    if (_newCtrl.text.length < 6) {
      setState(() => _errorMsg = 'La contraseña debe tener al menos 6 caracteres');
      return;
    }

    setState(() { _cargando = true; _errorMsg = null; _successMsg = null; });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.email == null) {
        setState(() => _errorMsg = 'No hay usuario autenticado');
        return;
      }

      // Reautenticar con la contraseña actual
      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: _currentCtrl.text,
      );

      await user.reauthenticateWithCredential(credential);

      // Cambiar la contraseña
      await user.updatePassword(_newCtrl.text);

      setState(() {
        _successMsg = 'Contraseña cambiada correctamente';
        _currentCtrl.clear();
        _newCtrl.clear();
        _confirmCtrl.clear();
      });

      // Cerrar el diálogo después de 1.5 segundos
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String msg = 'Error al cambiar la contraseña';
      if (e.code == 'wrong-password') {
        msg = 'La contraseña actual es incorrecta';
      } else if (e.code == 'weak-password') {
        msg = 'La nueva contraseña es muy débil';
      } else if (e.code == 'requires-recent-login') {
        msg = 'Por favor inicia sesión nuevamente';
      }
      setState(() => _errorMsg = msg);
    } catch (e) {
      setState(() => _errorMsg = 'Error inesperado: $e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final isSmallScreen = screenSize.width < 400;

    return Dialog(
      backgroundColor: Colors.transparent,
      child: SingleChildScrollView(
        child: Container(
          width: isSmallScreen ? screenSize.width * 0.9 : 400,
          padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1A2E),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFF4F46E5).withOpacity(0.3)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4F46E5).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.lock_outlined,
                      color: Color(0xFF818CF8), size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(child: Text('Cambiar contraseña',
                    style: TextStyle(color: Colors.white, fontSize: 16,
                        fontWeight: FontWeight.w700))),
                IconButton(
                  icon: const Icon(Icons.close, color: Color(0xFF6B7280)),
                  onPressed: () => Navigator.pop(context),
                  padding: const EdgeInsets.all(0),
                  constraints: const BoxConstraints(),
                ),
              ]),
              const SizedBox(height: 20),

              // Contraseña actual
              const Text('Contraseña actual',
                  style: TextStyle(color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _currentCtrl,
                obscureText: !_showCurrent,
                enabled: !_cargando,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ingresa tu contraseña actual',
                  hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                  filled: true,
                  fillColor: const Color(0xFF0D0D0D),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF4F46E5),
                      width: 1.5,
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showCurrent ? Icons.visibility : Icons.visibility_off,
                      color: const Color(0xFF6B7280),
                      size: 18,
                    ),
                    onPressed: () => setState(() => _showCurrent = !_showCurrent),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Nueva contraseña
              const Text('Nueva contraseña',
                  style: TextStyle(color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _newCtrl,
                obscureText: !_showNew,
                enabled: !_cargando,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Ingresa tu nueva contraseña',
                  hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                  filled: true,
                  fillColor: const Color(0xFF0D0D0D),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF4F46E5),
                      width: 1.5,
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showNew ? Icons.visibility : Icons.visibility_off,
                      color: const Color(0xFF6B7280),
                      size: 18,
                    ),
                    onPressed: () => setState(() => _showNew = !_showNew),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Confirmar contraseña
              const Text('Confirmar nueva contraseña',
                  style: TextStyle(color: Colors.white, fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              TextField(
                controller: _confirmCtrl,
                obscureText: !_showConfirm,
                enabled: !_cargando,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Confirma tu nueva contraseña',
                  hintStyle: const TextStyle(color: Color(0xFF6B7280)),
                  filled: true,
                  fillColor: const Color(0xFF0D0D0D),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.white.withOpacity(0.08)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(
                      color: Color(0xFF4F46E5),
                      width: 1.5,
                    ),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _showConfirm ? Icons.visibility : Icons.visibility_off,
                      color: const Color(0xFF6B7280),
                      size: 18,
                    ),
                    onPressed: () => setState(() => _showConfirm = !_showConfirm),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Mensajes de error y éxito
              if (_errorMsg != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7F1D1D).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_errorMsg!,
                        style: const TextStyle(color: Color(0xFFFCA5A5), fontSize: 12))),
                  ]),
                ),
              if (_successMsg != null)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF065F46).withOpacity(0.3),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF10B981).withOpacity(0.4)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.check_circle_outline, color: Color(0xFF10B981), size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_successMsg!,
                        style: const TextStyle(color: Color(0xFFA6F3E0), fontSize: 12))),
                  ]),
                ),
              const SizedBox(height: 20),

              // Botones
              Row(children: [
                Expanded(child: ElevatedButton(
                  onPressed: _cargando ? null : () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A1A2E),
                    foregroundColor: const Color(0xFF818CF8),
                    disabledBackgroundColor: const Color(0xFF1A1A2E).withOpacity(0.5),
                    side: BorderSide(color: const Color(0xFF4F46E5).withOpacity(0.3)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancelar', style: TextStyle(fontWeight: FontWeight.w600)),
                )),
                const SizedBox(width: 12),
                Expanded(child: ElevatedButton(
                  onPressed: _cargando ? null : _cambiarContrasena,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4F46E5),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: const Color(0xFF4F46E5).withOpacity(0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: _cargando
                      ? const SizedBox(width: 16, height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Cambiar', style: TextStyle(fontWeight: FontWeight.w600)),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}
