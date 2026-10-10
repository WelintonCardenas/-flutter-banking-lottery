// ─── widgets/horario_badge.dart ───────────────────────────────────────────────
//
// Uso:
//   HorarioBadge(horario: horarioLoteria)
//
// Muestra:
//   • Verde  "Abierta · cierra en Xm"   si está abierta
//   • Rojo   "Cerrada · abre a las HH:mm"  si está cerrada
//   • Gris   "Deshabilitada"             si activo=false

import 'package:flutter/material.dart';
import '../services/horario_service.dart';

class HorarioBadge extends StatelessWidget {
  final HorarioLoteria horario;
  const HorarioBadge({super.key, required this.horario});

  @override
  Widget build(BuildContext context) {
    final abierta = horario.estaAbierta();

    if (!horario.activo) {
      return _badge(
        color: Colors.grey.shade400,
        icon: Icons.block,
        texto: 'Deshabilitada',
      );
    }

    if (abierta) {
      final mins = horario.minutosParaCerrar();
      final label = mins >= 60
          ? 'Cierra en ${mins ~/ 60}h ${mins % 60}m'
          : 'Cierra en ${mins}m';
      return _badge(
        color: const Color(0xFF2ECC71),
        icon: Icons.check_circle_outline,
        texto: 'Abierta · $label',
      );
    } else {
      return _badge(
        color: const Color(0xFFE74C3C),
        icon: Icons.lock_clock,
        texto: horario.proximaApertura(),
      );
    }
  }

  Widget _badge({
    required Color color,
    required IconData icon,
    required String texto,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        border: Border.all(color: color.withOpacity(0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            texto,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}


// ─── Widget de lista completa de horarios ─────────────────────────────────────
//
// Uso en cualquier pantalla:
//   HorariosListView()
//
// Se actualiza en tiempo real desde Firebase.

class HorariosListView extends StatelessWidget {
  const HorariosListView({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Map<String, HorarioLoteria>>(
      stream: HorarioService.streamHorarios(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final horarios = snap.data ?? {};
        final lista    = horarios.values.toList()
          ..sort((a, b) => a.loteria.compareTo(b.loteria));

        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: lista.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (context, i) {
            final h = lista[i];
            return ListTile(
              dense: true,
              title: Text(
                h.loteria,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(h.horarioTexto),
              trailing: HorarioBadge(horario: h),
            );
          },
        );
      },
    );
  }
}
