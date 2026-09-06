# Estrategia para publicar en las tiendas

## 1. Categorización
- **Categoría Principal (iOS / Android):** **Educación (Education)**
- **Categoría Secundaria:** Herramientas / Utilidades (Utilities)
- Al colocarla en *Educación*, enmarcas la app en el ecosistema de herramientas de estudio y matemáticas, no en fotografía.

## 2. Notas para el Revisor de Apple (App Review Notes)
Cuando envíes la app a revisión en App Store Connect, incluye esta aclaración exacta en el campo de texto libre:

> **App Store Reviewer Note:**
> *"Esta aplicación es una herramienta pedagógica especializada en el estudio y validación de ejercicios de Razonamiento Abstracto y Visión Espacial para exámenes de admisión universitaria. A diferencia de un editor de fotos convencional, permite a los estudiantes concatenar múltiples ecuaciones de rotación angular (por ejemplo: +900° horario seguido de 77° antihorario), visualizar la trayectoria en un goniómetro con vueltas reducidas en el círculo unitario y verificar la imagen resultante paso a paso."*

## 3. Palabras clave y Subtítulo (SEO / ASO)
- **Subtítulo App Store (30 car.):** `Razonamiento y Visión Espacial` o `Calculadora de Rotaciones`
- **Palabras clave iOS (100 car.):** `razonamiento abstracto,examen admision,geometria,goniometro,rotacion imagenes,matematicas,simulacro,espacial`
- **Descripción corta Google Play (80 car.):** `Valida ejercicios de razonamiento abstracto y rotación angular paso a paso.` (alt: `Comprueba y valida ejercicios de rotación y razonamiento abstracto paso a paso.`)

## 4. Argumento técnico de arquitectura
El hecho de que la versión **web se mantenga en Astro para SEO** y la **versión nativa en Flutter maneje el cómputo pesado mediante `Isolates`** para no congelar la UI al procesar imágenes de alta resolución es un excelente argumento técnico de arquitectura para diferenciación y justificación de funcionalidad nativa.

## Checklist de entrega
- [ ] Screenshots con caso `900° + (-77°)` y goniómetro visible
- [ ] Video preview mostrando flujo: seleccionar imagen → agregar 2 operaciones → toggle trazo → ZIP pasos
- [ ] Descripción larga con fórmula $0°-360°$ normalizada
- [ ] Keywords sin repetir título/subtítulo (Apple penaliza duplicación)
- [ ] Review notes en inglés pegadas
- [ ] Categoría Educación marcada en ambas consolas
