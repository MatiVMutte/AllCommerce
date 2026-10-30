# AllCommerce — Features

Catálogo de funcionalidades: implementadas y backlog.
Objetivo del producto: que cualquier dueño de local tenga su propia app
de catálogo con IA que le ahorre tiempo — y que los clientes compren
por WhatsApp sin fricción.

Leyenda: ✅ implementada · 🔜 backlog

---

## Catálogo y productos

- ✅ **Catálogo público por local** — cada tienda tiene su página `/s/slug`
  con productos, categorías, buscador y datos del local. Gratis y sin login.
- ✅ **Variantes de producto** — talles/colores/etc. por producto; el cliente
  elige al agregar al carrito y viaja hasta el pedido, PDF y WhatsApp.
- ✅ **Multi-foto por producto** — galería de imágenes en la ficha.
- ✅ **Stock y "agotado"** — tracking opcional por producto; se puede
  pausar/reactivar sin borrar.
- ✅ **Precio mayorista** — precio y cantidad mínima por volumen.
- ✅ **Carga con IA (foto → ficha)** — Gemini analiza la foto del producto
  y completa título/descripción/categoría/tags.
- ✅ **Carga masiva** — varios productos en una pasada.
- 🔜 **Venta por fracción (kg/litro)** — cantidades decimales ("1.25 kg de
  arroz") en vez de unidades enteras. Queja #1 de usuarios de Kyte en
  almacenes/carnicerías.
- 🔜 **Foto de góndola multi-producto** — una foto de la repisa → la IA
  detecta 5-10 productos y crea fichas borrador para publicar en masa.
  Diferenciador demo-able.
- 🔜 **Alerta de stock bajo** — aviso al dueño cuando un producto queda
  por debajo de un umbral.
- 🔜 **Buscador inteligente** — búsqueda semántica ("algo para una picada")
  que matchea intención con productos reales de locales cercanos (Gemini).
- 🔜 **Lector de código de barras** — alta/búsqueda de productos por código.
- 🔜 **Favoritos de productos + alerta de oferta** — el cliente marca
  productos; si bajan de precio o pasan a oferta recibe push.
  Cierra el loop favorito→venta que la competencia no tiene.

## Pedidos y ventas

- ✅ **Carrito + pedido por WhatsApp** — el cliente arma el pedido y se
  manda al WhatsApp del local con ítems, variantes, totales y datos.
- ✅ **Gestión de pedidos** — estados (nuevo→confirmado→…→entregado),
  detalle, historial del dueño.
- ✅ **Re-pedido** — el cliente repite un pedido anterior desde su historial.
- ✅ **Delivery / retiro** — métodos de entrega, dirección y costo de envío.
- ✅ **Medios de pago configurables** — efectivo, transferencia, tarjetas
  (con filtro público "acepta tarjeta"), link de MercadoPago.
- ✅ **Cupones de descuento** — por código, validados en el checkout.
- ✅ **Exportar ventas a CSV** — pedidos del mes con ítems, variantes,
  totales, estado y datos comerciales. Listo para Excel.
- 🔜 **Zonas de delivery con costo** — zonas/radio con costo propio y
  pedido mínimo por zona. Pedido casi universal en reviews de la competencia.
- 🔜 **Pedido mínimo** — monto mínimo para aceptar pedidos (general o por
  método de entrega).
- 🔜 **Notificaciones al cliente** — push/WhatsApp cuando el pedido cambia
  de estado ("confirmado", "en camino", "listo"). La queja #1 de Tiendanube.
- 🔜 **Cobro con link de pago por pedido** — generar link de MercadoPago
  con el monto exacto del pedido.
- 🔜 **Pedidos programados** — "para las 20hs" / "paso mañana".
- 🔜 **Impresión de ticket/comanda** — ticket térmico o PDF para el local.
- 🔜 **Pantalla operativa de pedidos** — vista tipo cocina con los pedidos
  del día y su estado (restaurantes/locales con preparación).
- 🔜 **QR por mesa** — pedido directo desde la mesa (restaurantes).
- 🔜 **Repartidor / tracking de envío** — marcar "en camino" con repartidor
  asignado y seguimiento básico.
- 🔜 **Venta en mostrador (POS ligero)** — registrar venta presencial que
  descuente stock y sume a métricas, aunque no venga del catálogo.

## Dueño / panel

- ✅ **Panel del dueño** — métricas de ventas del mes, productos top,
  gestión de pedidos y productos.
- ✅ **Contador de visitas al catálogo** — visitas de la semana y total,
  deduplicadas por dispositivo/día. Solo el dueño las ve.
- ✅ **QR del catálogo** — descargable en PNG para imprimir y pegar en el
  mostrador/vidriera.
- ✅ **Horarios y abierto/cerrado** — horario de atención visible y
  toggle manual de apertura.
- ✅ **Marca del local** — logo, foto de portada, color principal.
- ✅ **Planes con enforcement real** — free (5 productos), trial y pagos;
  límite validado en la base de datos, no solo en la UI.
- 🔜 **Estadísticas avanzadas** — ventas por día/semana, ticket promedio,
  productos más vistos vs más vendidos, conversión de visitas.
- 🔜 **Multi-usuario por local** — empleados con permisos (solo pedidos,
  solo productos) y registro de quién hizo qué.
- 🔜 **Compras a proveedores** — cargar reposición de mercadería que
  alimente stock (pedido frecuente en Kyte).
- 🔜 **Campañas a clientes (CRM simple)** — avisar a clientes frecuentes
  por WhatsApp/push: ofertas, novedades, "hace X días no pedís".
- 🔜 **Respaldo/exportación completa** — descargar todos los datos del
  local (productos, pedidos, clientes). La queja de Tiendanube de "borran
  tus estadísticas" es la ventaja de ofrecer esto.

## Cliente / descubrimiento

- ✅ **Directorio de locales** — lista y mapa con todos los locales,
  filtro "cerca de vos" con distancia en km y "acepta tarjeta".
- ✅ **Perfil de cliente** — nombre, teléfono, dirección guardada.
- ✅ **Historial de pedidos** — con estado y re-pedido.
- ✅ **Notificaciones push** — registro de dispositivos (FCM).
- 🔜 **Reseñas de locales/productos** — valoración post-compra; arma
  confianza en el directorio.
- 🔜 **Recorrido multi-local** — el cliente arma una ruta de visita por
  varios locales del mapa (compras del barrio en una vuelta).
- 🔜 **Productos en oferta / vidriera de ofertas** — sección en el
  directorio con ofertas de todos los locales cercanos.
- 🔜 **Compartir producto** — link profundo a un producto concreto para
  mandar por WhatsApp/redes.

## Plataforma / admin / monetización

- ✅ **Multi-tenant con RLS** — un solo Supabase; aislamiento por
  `tenant_id` + políticas a nivel base de datos.
- ✅ **Panel de administración** — métricas globales, alta/gestión de
  tenants, asignación de planes.
- ✅ **Multi-plataforma** — una app Flutter: Android, Web (PWA en
  `allcommerce.mativmutte.workers.dev`) y Windows.
- 🔜 **Cap de pedidos por plan** — free con límite de pedidos/mes (modelo
  OlaClick), complementario al límite de productos.
- 🔜 **Moderación de locales inactivos** — ocultar del directorio locales
  sin actividad en X meses (la estafa/abandono es la queja #1 de Tiendanube).
- 🔜 **Agente IA en el WhatsApp del local** — contesta "¿tenés X? ¿cuánto
  sale?" con el catálogo real y toma pedidos solo. Lo que WAEngine/Appio
  cobran caro; el diferenciador más grande.
- 🔜 **Apps white-label por local** — generar APK/app premium con el
  branding de cada tienda (sin reescribir el MVP).
- 🔜 **Publicidad local / destacados** — locales promocionados en el
  directorio (ingreso adicional).
- 🔜 **Integración MercadoPago suscripciones** — cobro automático de
  planes mensuales.
- 🔜 **Modo offline / tolerancia a mala conexión** — cacheo del catálogo
  y de pedidos recientes (la inestabilidad es la queja #1 de OlaClick).
