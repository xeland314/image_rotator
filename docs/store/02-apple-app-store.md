# Apple App Store Connect — Ficha optimizada

**Posicionamiento:** Herramienta educativa y de estudio — calculadora visual de razonamiento abstracto

## Título (máx. 30 caracteres)
```
Rotador de Imágenes - Abstracto
```

## Subtítulo (máx. 30 caracteres)
```
Razonamiento y Visión Espacial
```
Alternativa: `Calculadora de Rotaciones`

## Palabras clave / Keywords (máx. 100 caracteres)
```
razonamiento abstracto,examen admision,rotacion imagenes,goniometro,geometria,simulacro,espacial,math
```
Variante SEO: `razonamiento abstracto,examen admision,geometria,goniometro,rotacion imagenes,matematicas,simulacro,espacial`

## Descripción

> Herramienta educativa especializada en la validación de ejercicios de razonamiento abstracto, geometría dinámica y visión espacial para preparación de exámenes de admisión universitaria y psicotécnicos.
>
> **Funcionalidades pedagógicas:**
> • **Cálculo Angular Compuesto:** Aplica sumas y restas de ángulos no múltiplos de 90° con normalización automática al rango de 0° a 360°.
> • **Auditoría Paso a Paso:** Examina la secuencia lógica de cada rotación individual para verificar dónde estuvo el error en la resolución manual.
> • **Trazo de Goniómetro:** Visualiza el ángulo efectivo y las revoluciones acumuladas mediante un lienzo gráfico superpuesto.
> • **Exportación ZIP y Galería:** Descarga el resultado final en máxima resolución o empaqueta la secuencia completa de pasos para guías docentes.
> • **Sin Conexión y Privado:** Procesamiento nativo acelerado por hardware sin recolección de datos ni conexión a internet requerida.

## Categoría
- Principal: **Educación (Education)**
- Secundaria: Utilities

## Qué la diferencia de un editor de fotos
Ninguna app de galería estándar (Fotos iOS, Google Fotos, editores comerciales) puede:
1. Concatenar ángulos arbitrarios no múltiplos de 90° (ej. $900° + (-77°) = 823° → 103° efectivos)
2. Descomponer paso a paso para auditar deducción lógica
3. Trazar goniómetro visual con vueltas completas acumuladas
4. Exportar secuencia en ZIP para resolucionarios

## Notas técnicas para argumentario
- Arquitectura: Web en Astro para SEO + Nativo Flutter con `Isolates` para cómputo pesado sin congelar UI
- Almacenamiento: `Hive` local hasta 100 operaciones, offline, privado
- Render: `CustomPainter` `TracePainter` para arcos y vectores
