# Notas para la Revisión — App Review Notes

Copia este texto en el campo libre de notas para el revisor en **App Store Connect** y **Google Play Console** para evitar rechazos bajo la norma **4.2 (Minimum Functionality)**.

## Texto en Inglés (recomendado para App Store Review)

> **NOTE FOR THE REVIEWER:**
> This application is a specialized **educational tool** designed for students and educators preparing for university entrance exams (Abstract Reasoning and Spatial Orientation tests).
> Unlike a standard image cropper or generic photo editor, this app serves as an **angular motion and spatial logic simulator**. Key core native functionalities include:
> 1. **Multi-Angle Accumulation Engine:** Compounds arbitrary rotation sequences (e.g., +900° clockwise followed by 77° counterclockwise = 103° effective angle) with degree normalization.
> 2. **Step-by-Step Educational Breakdown:** Renders intermediate steps sequentially so users can audit where they made a mistake in spatial reasoning problems.
> 3. **Custom Goniometer Canvas:** Draws custom vectors and arcs showing complete rotations over the image using `CustomPainter`.
> 4. **Batch ZIP Generation & Background Isolates:** Encodes and exports full step-by-step sequences into a `.zip` archive via background Dart Isolates to maintain UI responsiveness.
> 5. **Offline & Privacy-First Storage:** Uses local Key-Value storage (`Hive`) for problem history without sending data to external servers.
>
> **How to test:**
> 1. Select a sample image.
> 2. Add two distinct angle operations (e.g., `+900°` and `-77°`).
> 3. Toggle "Trazar arco goniómetro" to observe the visual angle vector.
> 4. Tap "ZIP pasos" to export the full step-by-step resolution bundle.
>
> Eso cambia **por completo** el panorama y elimina de raíz cualquier riesgo de rechazo por "falta de funcionalidad o simplicidad" (Guía 4.2 de Apple).

## Texto en Español (alternativa Google Play)

> **Nota para el revisor:**
> Esta aplicación es una herramienta pedagógica especializada en el estudio y validación de ejercicios de Razonamiento Abstracto y Visión Espacial para exámenes de admisión universitaria. A diferencia de un editor de fotos convencional, permite a los estudiantes concatenar múltiples ecuaciones de rotación angular (por ejemplo: +900° horario seguido de 77° antihorario), visualizar la trayectoria en un goniómetro con vueltas reducidas en el círculo unitario y verificar la imagen resultante paso a paso.

## Ventaja táctica (qué enfatizar)
Lo que tienes **no es un editor de fotos genérico**, sino una **calculadora visual de razonamiento abstracto y visión espacial**. Ninguna app de galería estándar puede:
1. Concatenar ángulos arbitrarios no múltiplos de 90° ($900° + (-77°) = 823° → 103° efectivos)
2. Descomponer paso a paso para auditar deducción
3. Trazar goniómetro con vueltas acumuladas
4. Exportar secuencia en ZIP para guías de estudio
