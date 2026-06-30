import 'package:flutter/material.dart';



import '../core/theme/app_theme.dart';

import '../core/utils/currency_formatter.dart';

import '../data/models/appointment.dart';



class AppointmentCard extends StatelessWidget {

  const AppointmentCard({

    super.key,

    required this.appointment,

    required this.onTap,

  });



  final Appointment appointment;

  final VoidCallback onTap;



  @override

  Widget build(BuildContext context) {

    return Card(

      child: ListTile(

        leading: CircleAvatar(

          backgroundColor: AppTheme.accent.withValues(alpha: 0.2),

          child: Text(

            appointment.time,

            style: const TextStyle(

              fontSize: 11,

              fontWeight: FontWeight.bold,

              color: AppTheme.accent,

            ),

          ),

        ),

        title: Text(

          appointment.clientName,

          style: const TextStyle(fontWeight: FontWeight.w600),

        ),

        subtitle: Text(

          [

            if (appointment.barberName != null) appointment.barberName!,

            appointment.servicesLabel,

            if (appointment.totalPrice > 0)

              CurrencyFormatter.format(appointment.totalPrice),

          ].join(' · '),

        ),

        trailing: const Icon(Icons.chevron_right),

        onTap: onTap,

      ),

    );

  }

}

