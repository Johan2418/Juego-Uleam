# Generaciones hechas por Claude en Runway (cuenta conectada: Alyson Melina)
Cada una se puede recuperar por su taskId (Runway MCP get_task) y guardar en _entregas_runway/ con el nombre indicado.

| Archivo destino | taskId | Estado |
|---|---|---|
| wadrid_roll_right.png | e3380cb0-2e9d-457e-8099-9e0397ab5e85 | OK revisado |
| wadrid_roll_down.png | f9d00d41-f9f6-4aec-b127-1681f3d28f8e | OK revisado |
| wadrid_roll_up.png | f88bcaff-2145-4de6-8482-e10489bdff26 | OK revisado |
| wadrid_guerrero_attack_down.png | cb53c650-d62a-4b4a-90db-c12371eab557 | OK revisado |
| wadrid_guerrero_attack_up.png | 66f99276-0422-4c88-97ec-e505e4d79f2e | OK revisado |
| wadrid_mago_cast_right.png | d6a7255f-90da-408e-aed1-044f2c29c088 | OK revisado |
| wadrid_mago_cast_down.png | 895a52a2-288b-413c-9e02-91b94ca7a14c | OK (pose 4 cambia de mano: usar pose 1 como recuperación) |
| wadrid_mago_cast_up.png | 022af4bc-972e-4405-a17b-87163d82a485 | OK revisado |
| wadrid_chain_whip_right.png | 3e2558c8-407b-48e4-822f-bd784b8c3fe1 | OK revisado |
| wadrid_chain_whip_down.png | cb491baf-7fd3-4fce-97d6-1a27dbe732bf | OK (latigazo poco marcado) |
| wadrid_chain_whip_up.png | 1181bd6a-a46e-4b3f-8ee1-f35ef7fadda5 | OK revisado |
| marlonx_a_walk_down.png | 8b310a15-0a40-4842-9b9d-a2b4adb66347 | OK revisado |
| marlonx_a_walk_up.png | 6f79ef40-574d-43d6-bf0d-2654f78bf874 | OK revisado |
| marlonx_a_walk_right.png | 7d70af66-464c-4f7d-bec1-42e9f974e340 | sin revisar |
| marlonx_a_roll_right.png | ed3f863b-ed01-4e88-9a2e-2fb37df10dd6 | sin revisar |
| marlonx_a_guerrero_attack_right.png | 92e705df-fc45-42eb-b65b-16ae69b7ae7d | sin revisar |
| marlonx_a_guerrero_attack_down.png | 62ac34d3-9ff7-4fee-81a9-5f513bc5128b | sin revisar |
| marlonx_a_guerrero_attack_up.png | 6af955f7-0baa-4467-bfec-7bcf9cf558a6 | sin revisar |
| marlonx_a_mago_cast_right.png | 049d69f1-9a5c-4be6-9485-6df6b79c6857 | OK revisado |
| marlonx_a_mago_cast_down.png | b5e07028-8e05-43a9-8a36-b23cd8420192 | rehecho, sin revisar (DESCARTAR f57c83df-0099-4111-ac42-27a417db09c4: otro estilo) |
| marlonx_a_mago_cast_up.png | b5670290-2292-4233-af50-f41576ceb94e | OK revisado |
| marlonx_a_chain_whip_right.png | e8085723-0183-4f6e-9e40-d673994d8276 | sin revisar |
| marlonx_a_chain_whip_down.png | 03ab3f77-fff4-4637-9329-942811cf1eb5 | sin revisar |
| marlonx_a_chain_whip_up.png | 232765ba-18f0-4053-aded-100c6ee09a78 | sin revisar |
| marlonx_a_roll_down.png | 41e670e8-558d-4e69-84ce-ac14df9dd5ce | OK revisado (cuenta Alyson, 2026-09-26) |
| marlonx_a_roll_up.png | d65103b9-43f1-41ea-a0eb-144400fdbe86 | OK (de espaldas pero algo en diagonal; pose 2 = zambullida) |

## Pendiente
- Especiales, parry, ultimates y efectos (fases 2-4)

## Descargado (2026-09-26)
Todas las hojas de fase 1 (excepto marlonx_a_roll_down / roll_up, sin generar) estan en _entregas_runway/ con su nombre final y revisadas.

## Fase 1 completa (2026-09-26)
Las 30 hojas están en _entregas_runway/. Recorte a frames: `python3 tools/slice_character_sheets.py`
-> assets/sprites/characters_anim/<personaje>/ (+ _preview.png para revisar).
Nota de red: desde la sesión de Claude no se pudo subir/descargar directo a Runway (proxy);
las referencias ya estaban en Assets y las hojas nuevas las descargó el usuario.

## Fase combo — remates del ataque leve (2026-09-26, cuenta Alyson)
Combo J: golpe 1 y 2 = mitades del ataque base (ya existentes); golpe 3 = remate (hoja nueva).
Guardar en _entregas_runway/ con estos nombres y correr `python3 tools/slice_character_sheets.py`.

| Archivo destino | taskId | Estado |
|---|---|---|
| wadrid_guerrero_finisher_right.png | 9f4f39e1-4727-4c89-b451-0f16d119f110 | OK revisado (salto + golpe) |
| marlonx_a_guerrero_finisher_right.png | 72a4813f-1628-4691-999c-af4854699000 | OK revisado |
| wadrid_mago_finisher_right.png | d8736eb8-2b86-42e9-921c-33b064fbd24a | OK revisado |
| marlonx_a_mago_finisher_right.png | 2d8b8b93-0136-4e4a-82c6-d3da8ccc5610 | OK revisado |
| wadrid_chain_finisher_right.png | 4320e235-2719-49b5-9867-8a8881a708fb | OK (chispas pequeñas en la punta del cable) |
| marlonx_a_chain_finisher_right.png | a247c63b-3ca7-4a2c-8de8-9ef7ff9a9132 | OK revisado |
| wadrid_guerrero_finisher_down.png | 10db0dec-1c74-4941-80cf-ce1f256df2e7 | OK (pose 4 lleva el borrador en la mano) |
| marlonx_a_guerrero_finisher_down.png | 432d8041-b65d-468f-8532-6de8ad11ca10 | OK revisado |
| wadrid_mago_finisher_down.png | 5eb8a0a8-ffd4-49fb-8ae4-5334d346a8ce | OK revisado |
| marlonx_a_mago_finisher_down.png | 34957771-b5ff-4880-b472-8565643fcf1f | OK revisado |

Las 10 hojas de arriba ya están en _entregas_runway/ y recortadas (remates escalados con la pose 4 de pie; la pose 2 del guerrero se sube 12 px por el salto).

### Generadas con la cuenta Johan (2026-09-26) — reusando las URLs de referencia de la cuenta Alyson
| Archivo destino | taskId | Estado |
|---|---|---|
| wadrid_guerrero_finisher_up.png | fa843e08-d2b6-4be8-9e35-b25c83d87aaf | OK revisado |
| marlonx_a_guerrero_finisher_up.png | a4d62413-18b4-4121-b0cc-54477242f9f1 | OK revisado |
| wadrid_mago_finisher_up.png | a42db1ed-4aaa-400f-a21c-0f5b54fb129e | OK revisado |
| marlonx_a_mago_finisher_up.png | b04cb7cf-dcb4-46fc-a232-5d22a536be35 | OK revisado |
| wadrid_chain_finisher_up.png | a895136c-9913-4632-85c4-779293c7fa28 | OK revisado |
| marlonx_a_chain_finisher_up.png | c71a1e69-9ea7-4961-ba4a-04be91b92b47 | OK revisado |
| wadrid_chain_finisher_down.png | 42eae441-8cab-4836-bedc-4c858da85a38 | OK revisado |
| marlonx_a_chain_finisher_down.png | 5a8407b9-6830-4b31-91f0-b0f53a9f4e33 | OK revisado |
Con estas, los remates quedan completos (3 clases × 3 direcciones × 2 personajes). Guardadas en _entregas_runway/, recortadas e integradas (2026-09-26).

## Caminata nueva — ciclo real de 4 pasos en 8 direcciones (2026-09-26, cuenta Johan)
Las hojas walk originales NO eran un ciclo (2 poses quietas + 2 pasos girados en diagonal). Se copiaron a
`<id>_idle_<dir>.png` (el reposo usa su pose 1) y el original quedó en `referencias_animacion/_walk_viejo/`.
Poses: 1 pie izq. adelante, 2 paso (pies juntos), 3 pie der. adelante, 4 paso. Izquierdas = espejo.

| Archivo destino | taskId | Estado |
|---|---|---|
| wadrid_walk_down.png | f1cb2fd0-f7b7-4722-bd0e-b37a80a90d1d | OK revisado |
| marlonx_a_walk_down.png | 857a0bf6-bdf9-4e25-b6d5-8210d0fddabb | OK revisado |
| wadrid_walk_up.png | 6938c812-80cc-401a-90e0-c222b014524f | OK revisado |
| marlonx_a_walk_up.png | 9cf403f6-efa6-4fc3-b704-520283a356d8 | OK revisado |
| wadrid_walk_right.png | 700512c0-da01-457b-8472-ace333093b16 | OK revisado |
| marlonx_a_walk_right.png | 1a2c1043-5d48-4812-b677-d9ac9b2ce817 | OK revisado |
| wadrid_walk_down_right.png | 7dbd1983-536b-4aa4-85a2-647e153e3af2 | OK revisado |
| marlonx_a_walk_down_right.png | ebff75b2-29a1-4acd-8e36-ce9d0fefdcdb | OK revisado |
| wadrid_walk_up_right.png | 23129b68-8923-42e5-beb2-5d53d38f2b44 | OK revisado |
| marlonx_a_walk_up_right.png | 49230298-4982-40b6-8f0e-6cbdef83aa93 | OK revisado |

Las 10 hojas de caminata nueva ya están en _entregas_runway/, recortadas e integradas (2026-09-26): walk en 8 direcciones + idle desde las hojas viejas.
