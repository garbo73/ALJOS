# ALJOS – adaptación conservadora para Fire TV Stick 2.ª generación (AFTT)

Esta copia está preparada para **probar primero la aplicación sin modificar el sistema** del Fire TV Stick 2.ª generación (Fire OS 5.1.1 / Android API 22).

## Cambios de seguridad
- Mantiene `minSdkVersion=22` y `targetSdkVersion=22`.
- El instalador ADB instala y abre ALJOS, pero **no activa automáticamente Accesibilidad** ni cambia ajustes seguros del sistema.
- No desactiva ni elimina el launcher de Amazon.
- La función `debloat` queda bloqueada: en este modelo los comandos de desactivación de paquetes han sido rechazados y no se deben forzar.
- `undo` no desinstala ni modifica el launcher de Amazon.

## Requisitos para compilar
Java 17, Android SDK platform 34 y build-tools 34.0.0. Ejecuta `./build.sh`. El APK se genera en `out/ALJOS.apk`.

## Instalar desde un ordenador con ADB
1. Activa ADB debugging en el Fire TV y conecta por Wi-Fi.
2. Ejecuta `./aljos.sh install DIRECCION_IP` (por ejemplo, `./aljos.sh install 192.168.1.152`).
3. Abre ALJOS desde Aplicaciones y comprueba navegación, mando y apertura de apps.
4. No cambies la app HOME predeterminada ni desactives paquetes de Amazon.

## Limitación importante
El servicio de Accesibilidad que intenta cubrir la pantalla HOME de Amazon requiere que Fire OS permita activarlo y mostrar ventanas `TYPE_ACCESSIBILITY_OVERLAY`. La compatibilidad API 22 permite compilar la app, pero **no garantiza** que el firmware AFTT autorice ese comportamiento. Primero hay que comprobarlo en el dispositivo. Si el servicio no se puede activar, ALJOS seguirá disponible como aplicación normal y Amazon HOME seguirá funcionando.

## Deshacer
`./aljos.sh undo DIRECCION_IP` elimina únicamente la entrada de servicio de accesibilidad de ALJOS si existía y restablece las escalas de animación. No desinstala la app salvo que se solicite expresamente con `--uninstall`.


## Variante con iconos a todo color

Esta versión elimina el filtro de escala de grises aplicado a los iconos de las aplicaciones instaladas. Los iconos se cargan desde el propio paquete de cada aplicación, conservando sus colores originales. No cambia el fondo, el reloj, la barra horizontal, el resaltado azul ni los ajustes del launcher.

### Compilar con GitHub Actions desde el móvil

1. Sube el contenido de esta carpeta `aljos` a la raíz de un repositorio de GitHub.
2. Abre **Actions** y ejecuta **Build ALJOS APK** (o haz un push de los cambios).
3. Descarga el artefacto **ALJOS-APK-iconos-color**.
4. Instala el APK sobre la versión existente. Una compilación nueva tendrá una firma distinta salvo que se use la misma clave de firma.

No desinstales la versión que ya funciona hasta tener el nuevo APK y confirmar que puedes instalarlo como actualización.
