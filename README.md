# ClubRobot — Missão 12: Roleta da Sorte

App Flutter para crianças a partir de 6 anos. A criança gira a roleta física, seleciona a cor que saiu, recebe um desafio aleatório daquela categoria e tem 20 segundos para realizá-lo. Quando o ESP32 está conectado por Bluetooth BLE, um LED acende no início e apaga ao terminar o cronômetro.

## Identidade visual

Segue a estética do app Guincho Inteligente da Missão 14: fundo claro, cards arredondados, tipografia forte, turquesa ClubRobot (#20C6C8), laranja (#FF7A00) e logo oficial do ClubRobot.

## Cores e categorias

- Roxo escuro: Bichos Malucos
- Roxo claro: Roleta das Caretas
- Azul: Passinho Robótico
- Verde: Caça às Cores
- Amarelo A: Cérebro Turbo
- Laranja: Desafio Maluco
- Amarelo B: Mestre das Palavras
- Vermelho: Desafio Relâmpago

## Montagem do LED

1. GPIO 18 do ESP32 -> resistor de 220 a 330 ohms -> perna longa (ânodo) do LED.
2. Perna curta (cátodo) do LED -> GND.
3. Alimente o ESP32 pelo USB durante os testes.
4. O firmware apaga o LED se o celular desconectar e inclui um limite de segurança de 60 segundos ligado.

Confira o pinout do seu modelo de ESP32 antes de montar. O sketch é direcionado ao ESP32-WROOM/DevKit clássico e usa a API BLE Arduino do ESP32.

## Firmware

Abra esp32/roleta_missao12.ino na Arduino IDE, selecione a placa ESP32 adequada e grave o firmware. O dispositivo BLE anuncia ESP32_ROLETA.

## Gerar APK pelo GitHub Actions

O workflow .github/workflows/build-apk.yml compila o APK na nuvem.

1. Abra a aba Actions no GitHub.
2. Escolha **Gerar APK Android - Roleta da Sorte**.
3. Clique em **Run workflow**.
4. Quando terminar, abra a execução e baixe o artifact **roleta-missao12-apk**.
5. Dentro do ZIP estará app-release.apk.

O workflow executa flutter analyze lib antes da compilação. Se falhar, abra os logs da etapa que ficou vermelha para identificar a causa.

## BLE

O app usa o mesmo par de UUIDs do projeto Guincho Missão 14:

- Serviço: 6f400001-b5a3-f393-e0a9-e50e24dcca9e
- Característica: 6f400002-b5a3-f393-e0a9-e50e24dcca9e

Comandos: START (acende o LED) e STOP (apaga o LED).
