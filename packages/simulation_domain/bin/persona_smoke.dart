import 'dart:convert';

import 'package:cycle_simulation_domain/simulation_domain.dart';

void main(List<String> args) {
  final seedArg = args.where((value) => value.startsWith('--seed=')).firstOrNull;
  final seed = int.tryParse(seedArg?.substring('--seed='.length) ?? '') ?? 20260915;
  const generator = PersonaGenerator();
  final personas = <SimulationPersona>[
    generator.patient(seed),
    generator.partner(seed + 1),
    generator.doctor(seed + 2),
  ];
  print(jsonEncode({'schemaVersion': personaSchemaVersion, 'seed': seed, 'personas': personas.map((persona) => persona.toJson()).toList()}));
}
