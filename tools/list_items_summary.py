import os

roster_dir = 'data/items/roster'

overclocks = ['fusion_reactor', 'dense_turbine', 'collimator_lens', 'split_salvo', 'rapid_injector', 'nanotitanium_plating', 'afterburn_thruster', 'tachyon_prism']
procs = ['tesla_coil', 'kinetic_plating', 'phase_thruster', 'retaliation_swarm', 'entropy_catalyst', 'phase_inverter', 'pyroclastic_battery', 'cryo_condenser']
conversions = ['alchemical_converter', 'hemodynamic_cell', 'kinetic_converter', 'gravitational_resonator', 'photonic_transducer', 'overdrain_module', 'static_cell', 'stellar_scrap']
strategics = ['abyssal_contract', 'antimatter_core', 'blood_capacitor', 'entropy_engine', 'bifocal_lens', 'inertial_thruster', 'chain_battery', 'photonic_prism', 'orbital_relay', 'quantum_recompiler', 'heavy_salvager', 'chronos_bank']

canonical_ids = [
	'botas', 'espada', 'escudo', 'corazon', 'manzana', 'iman',
	'gafas', 'lupa', 'guante', 'trebol', 'carcaj', 'chip_telemetria',
	'propulsor', 'lente_amplificadora', 'reloj_cuantico',
	'moneda_oro', 'capsula_biomasa', 'reliquia_maldita',
	'glass_reactor', 'heavy_condenser', 'tachyon_piercer',
	'quantum_key', 'credit_card_green', 'credit_card_red'
]

def get_item(i_id):
    p = os.path.join(roster_dir, f'{i_id}.tres')
    if not os.path.exists(p): return (i_id, 'No desc')
    content = open(p, encoding='utf-8').read().splitlines()
    name = i_id
    desc = ''
    for l in content:
        if l.startswith('item_name ='):
            name = l.split('=', 1)[1].strip().strip('"')
        elif l.startswith('description ='):
            desc = l.split('=', 1)[1].strip().strip('"')
    return (name, desc)

print('=== 1. SOBRECARGAS CON TRADE-OFF (SATÉLITE) ===')
for i in overclocks:
    n, d = get_item(i)
    print(f'* **{n}**: {d}')

print('\n=== 2. PROCS REACTIVOS (SATÉLITE / COMBATE) ===')
for i in procs:
    n, d = get_item(i)
    print(f'* **{n}**: {d}')

print('\n=== 3. NÚCLEOS DE CONVERSIÓN Y UTILIDAD (SATÉLITE) ===')
for i in conversions:
    n, d = get_item(i)
    print(f'* **{n}**: {d}')

print('\n=== 4. MÓDULOS ESTRATÉGICOS (SATÉLITE) ===')
for i in strategics:
    n, d = get_item(i)
    print(f'* **{n}**: {d}')

print('\n=== 5. ESTADÍSTICAS BÁSICAS Y ECONOMÍA (COFRES) ===')
for i in canonical_ids:
    n, d = get_item(i)
    print(f'* **{n}**: {d}')
