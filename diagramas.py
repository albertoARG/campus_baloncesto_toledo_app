# -*- coding: utf-8 -*-
"""Genera los diagramas tecnicos del TFG con el estilo visual de la app."""
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, FancyArrowPatch, Ellipse, Circle
from matplotlib.lines import Line2D

PRIMARY = "#5E35B1"
PRIMARY_D = "#4527A0"
LIGHT = "#EDE7F6"
MED = "#B39DDB"
ACCENT = "#FF9800"
ACCENT_L = "#FFE0B2"
GREEN = "#43A047"
GREEN_L = "#E8F5E9"
BLUE = "#1E88E5"
BLUE_L = "#E3F2FD"
GREY = "#90A4AE"
TXT = "#212121"


def box(ax, x, y, w, h, text, fc=LIGHT, ec=PRIMARY, fs=10, fw="normal",
        tc=TXT, lw=1.6, round_size=0.06, va="center"):
    p = FancyBboxPatch((x, y), w, h,
                       boxstyle=f"round,pad=0.01,rounding_size={round_size}",
                       fc=fc, ec=ec, lw=lw, zorder=2)
    ax.add_patch(p)
    ax.text(x + w / 2, y + h / 2, text, ha="center", va=va, fontsize=fs,
            fontweight=fw, color=tc, zorder=3)


def arrow(ax, p1, p2, color=PRIMARY_D, lw=1.6, style="-|>", ls="-"):
    a = FancyArrowPatch(p1, p2, arrowstyle=style, mutation_scale=14,
                        color=color, lw=lw, linestyle=ls, zorder=1,
                        shrinkA=2, shrinkB=2)
    ax.add_patch(a)


def biarrow(ax, p1, p2, color=PRIMARY_D, lw=1.6):
    a = FancyArrowPatch(p1, p2, arrowstyle="<|-|>", mutation_scale=12,
                        color=color, lw=lw, zorder=1, shrinkA=2, shrinkB=2)
    ax.add_patch(a)


def newfig(w, h):
    fig, ax = plt.subplots(figsize=(w, h))
    ax.set_xlim(0, 100)
    ax.set_ylim(0, 100)
    ax.axis("off")
    return fig, ax


def save(fig, name):
    fig.savefig(name, dpi=200, bbox_inches="tight", facecolor="white", pad_inches=0.15)
    plt.close(fig)
    print("OK", name)


# ===========================================================================
# 1) ARQUITECTURA  (Clean Architecture en capas)
# ===========================================================================
def arquitectura():
    fig, ax = newfig(9.5, 11)
    ax.text(50, 97, "Arquitectura del sistema (Clean Architecture por funcionalidades)",
            ha="center", va="center", fontsize=12.5, fontweight="bold", color=PRIMARY)

    x, w = 8, 84
    layers = [
        (82, 9, "CAPA DE PRESENTACIÓN",
         "Pantallas y widgets de Flutter · Material Design 3 · Navegación declarativa con go_router", LIGHT),
        (70, 8.5, "GESTIÓN DE ESTADO",
         "Riverpod · Providers, FutureProvider, StreamProvider y AsyncNotifier", LIGHT),
        (58, 8.5, "CAPA DE DATOS — REPOSITORIOS",
         "AuthRepository · CompetitionsRepository · SiestaRepository · BlogRepository · VeladasRepository · …", LIGHT),
        (46, 8.5, "SERVICIOS",
         "NotificationService (FCM) · CloudinaryService · ExportService (Excel) · SiestaExportService (PDF)", LIGHT),
    ]
    for (yy, hh, title, sub, fc) in layers:
        box(ax, x, yy, w, hh, "", fc=fc, ec=PRIMARY, lw=1.8)
        ax.text(50, yy + hh - 2.4, title, ha="center", va="center",
                fontsize=11, fontweight="bold", color=PRIMARY_D)
        ax.text(50, yy + 2.3, sub, ha="center", va="center", fontsize=8.6, color=TXT)

    # Backend layer with 3 external services
    by, bh = 26, 13
    box(ax, x, by, w, bh, "", fc="#F3E5F5", ec=PRIMARY, lw=1.8)
    ax.text(50, by + bh - 2.2, "BACKEND Y SERVICIOS EXTERNOS (BaaS)",
            ha="center", va="center", fontsize=11, fontweight="bold", color=PRIMARY_D)
    sw = 25
    box(ax, 11, by + 1.8, sw, 7.2,
        "Supabase\nPostgreSQL · Auth\nRealtime · RLS", fc=GREEN_L, ec=GREEN, fs=8.8, fw="bold", tc="#1B5E20")
    box(ax, 11 + sw + 2.5, by + 1.8, sw, 7.2,
        "Firebase\nCloud Messaging\n(notificaciones push)", fc=ACCENT_L, ec=ACCENT, fs=8.8, fw="bold", tc="#E65100")
    box(ax, 11 + 2 * (sw + 2.5), by + 1.8, sw, 7.2,
        "Cloudinary\nAlmacenamiento\nde imágenes", fc=BLUE_L, ec=BLUE, fs=8.8, fw="bold", tc="#0D47A1")

    # vertical bidirectional arrows between layers (left + right rails)
    pairs = [(91, 82), (79.5, 70), (67, 58.5), (55, 46), (45, 39)]
    for (ytop, ybot) in pairs:
        biarrow(ax, (28, ytop), (28, ybot))
        biarrow(ax, (72, ytop), (72, ybot))

    ax.text(2.5, 60, "Flujo de datos", rotation=90, ha="center", va="center",
            fontsize=9, color=GREY, fontstyle="italic")
    save(fig, "arquitectura.png")


# ===========================================================================
# 2) MODELO DE DATOS (Entidad-Relacion simplificado, agrupado por modulos)
# ===========================================================================
def modelo_datos():
    fig, ax = newfig(13, 9.5)
    ax.text(50, 98, "Modelo de datos — principales entidades y relaciones",
            ha="center", va="center", fontsize=12.5, fontweight="bold", color=PRIMARY)

    def tbl(x, y, w, h, name, fields, fc=LIGHT, ec=PRIMARY):
        box(ax, x, y, w, h, "", fc="white", ec=ec, lw=1.5, round_size=0.04)
        # header
        hh = 4.2
        head = FancyBboxPatch((x, y + h - hh), w, hh,
                              boxstyle="round,pad=0.01,rounding_size=0.04",
                              fc=ec, ec=ec, lw=1.5, zorder=2)
        ax.add_patch(head)
        ax.text(x + w / 2, y + h - hh / 2, name, ha="center", va="center",
                fontsize=8.4, fontweight="bold", color="white", zorder=3)
        ax.text(x + 1.2, y + h - hh - 1.3, fields, ha="left", va="top",
                fontsize=6.7, color=TXT, zorder=3, linespacing=1.25)
        return (x, y, w, h)

    # central
    users = tbl(40, 70, 20, 16, "users",
                "PK id\nrole\nnombre, apellidos\nposicion, nivel\nfoto_url", ec=PRIMARY_D)

    # teams module (left top)
    teams = tbl(8, 78, 18, 11, "teams", "PK id\nnombre\ncategoria", ec=GREEN)
    tmem = tbl(8, 62, 18, 11, "team_members", "FK team_id\nFK user_id", ec=GREEN)

    # trainings
    trn = tbl(8, 46, 18, 11, "trainings", "PK id\nFK team_id\nFK coach_id\ntitulo, fecha", ec=GREEN)

    # comunicacion (left bottom)
    blog = tbl(8, 26, 18, 12, "blog_posts", "PK id\nFK author_id\ntitle, content\nimage_urls[]", ec=BLUE)
    tab = tbl(8, 10, 18, 11, "tablon_posts", "PK id\nFK author_id\nis_staff_only", ec=BLUE)
    fcm = tbl(30, 10, 16, 11, "fcm_tokens", "PK id\nFK user_id\ntoken, platform", ec=ACCENT)
    pms = tbl(30, 28, 18, 12, "player_match_stats",
              "PK id\nFK user_id\npoints, rebounds\nassists, is_mvp", ec=PRIMARY)

    # estaciones (right top)
    stt = tbl(74, 80, 17, 10, "stations", "PK id\nnombre", ec=GREEN)
    sdy = tbl(74, 67, 17, 10, "station_days", "PK id\nnombre, fecha", ec=GREEN)
    ssc = tbl(74, 52, 18, 12, "station_scores",
              "PK id\nFK user_id\nFK station_id\nFK station_day_id\nscore", ec=GREEN)

    # siesta (right mid-bottom)
    scp = tbl(54, 70, 18, 12, "siesta_competitions",
              "PK id\nnombre, juego\nformato, estado", ec=ACCENT)
    spt = tbl(54, 52, 18, 13, "siesta_participants",
              "PK id\nFK competition_id\nFK user_id\npuntos_liga, grupo", ec=ACCENT)
    smt = tbl(74, 34, 18, 13, "siesta_matches",
              "PK id\nFK competition_id\nFK participant1_id\nFK participant2_id\nscore1, score2, ronda", ec=ACCENT)
    sds = tbl(54, 34, 18, 12, "siesta_daily_scores",
              "PK id\nFK competition_id\nFK user_id\nfecha, puntos", ec=ACCENT)

    # veladas (bottom center-right)
    vel = tbl(54, 16, 16, 11, "veladas", "PK id\nnombre, fecha", ec=PRIMARY)
    vgr = tbl(74, 16, 16, 11, "velada_groups", "PK id\nFK velada_id\nis_winner", ec=PRIMARY)

    def edge(a, b, color=GREY):
        ax1 = a[0] + a[2] / 2; ay1 = a[1] + a[3] / 2
        bx1 = b[0] + b[2] / 2; by1 = b[1] + b[3] / 2
        ax.add_line(Line2D([ax1, bx1], [ay1, by1], color=color, lw=1.0, zorder=0, alpha=0.7))

    for b in [teams, tmem, trn, blog, tab, fcm, pms, ssc, spt, sds, vel]:
        edge(users, b)
    edge(teams, tmem); edge(teams, trn)
    edge(stt, ssc); edge(sdy, ssc)
    edge(scp, spt); edge(scp, smt); edge(scp, sds); edge(spt, smt)
    edge(vel, vgr)

    # module legend
    leg = [(PRIMARY_D, "Usuarios / núcleo"), (GREEN, "Equipos · estaciones · entrenamientos"),
           (ACCENT, "Competiciones de siesta"), (BLUE, "Comunicación"),
           (PRIMARY, "Veladas · estadísticas")]
    lx = 2
    for i, (c, t) in enumerate(leg):
        ax.add_patch(FancyBboxPatch((lx, 2 + i * 0), 2, 1.6, boxstyle="round,pad=0.01",
                                    fc=c, ec=c)) if False else None
    # simple legend row
    yy = 3.0
    xx = 2
    for c, t in leg:
        ax.add_patch(plt.Rectangle((xx, yy), 2, 1.8, fc=c, ec=c, zorder=3))
        ax.text(xx + 2.6, yy + 0.9, t, ha="left", va="center", fontsize=7, color=TXT)
        xx += 2.6 + len(t) * 0.95 + 2
    save(fig, "modelo_datos.png")


# ===========================================================================
# 3) CASOS DE USO (UML)
# ===========================================================================
def casos_uso():
    fig, ax = newfig(12, 10)
    ax.text(50, 98, "Diagrama de casos de uso", ha="center", va="center",
            fontsize=12.5, fontweight="bold", color=PRIMARY)

    def actor(x, y, label, color=PRIMARY_D):
        ax.add_patch(Circle((x, y + 6), 1.6, fc="white", ec=color, lw=1.8, zorder=3))
        ax.add_line(Line2D([x, x], [y + 4.4, y - 1], color=color, lw=1.8, zorder=3))
        ax.add_line(Line2D([x - 2.6, x + 2.6], [y + 2.5, y + 2.5], color=color, lw=1.8, zorder=3))
        ax.add_line(Line2D([x, x - 2.2], [y - 1, y - 5], color=color, lw=1.8, zorder=3))
        ax.add_line(Line2D([x, x + 2.2], [y - 1, y - 5], color=color, lw=1.8, zorder=3))
        ax.text(x, y - 8, label, ha="center", va="center", fontsize=8.6,
                fontweight="bold", color=color)

    # system boundary
    box(ax, 24, 6, 52, 84, "", fc="#FAF7FF", ec=PRIMARY, lw=1.8, round_size=0.02)
    ax.text(50, 87.5, "Campus Baloncesto App", ha="center", va="center",
            fontsize=9.5, fontweight="bold", color=PRIMARY, fontstyle="italic")

    # actors left
    actor(9, 74, "Administrador")
    actor(9, 44, "Entrenador")
    # actors right
    actor(91, 70, "Jugador /\nJ. premium")
    actor(91, 40, "Familiar /\nVisitante")

    uc = [
        (50, 82, "Autenticarse / gestionar perfil"),
        (50, 75, "Gestionar usuarios y roles"),
        (50, 68, "Gestionar equipos y generarlos\nautomáticamente"),
        (50, 61, "Crear y gestionar competiciones"),
        (50, 54, "Registrar resultados de partidos"),
        (50, 47, "Gestionar competiciones de siesta"),
        (50, 40, "Exportar clasificación de siesta a PDF"),
        (50, 33, "Exportar clasificación por estaciones a Excel"),
        (50, 26, "Publicar en blog y tablón"),
        (50, 19, "Consultar clasificaciones y estadísticas"),
        (50, 12, "Recibir notificaciones push"),
    ]
    centers = {}
    for (x, y, t) in uc:
        ax.add_patch(Ellipse((x, y), 40, 5.4, fc=LIGHT, ec=PRIMARY, lw=1.3, zorder=2))
        ax.text(x, y, t, ha="center", va="center", fontsize=7.6, color=TXT, zorder=3)
        centers[t] = (x, y)

    def link(actor_xy, t, side):
        cx, cy = centers[t]
        ex = cx - 20 if side == "L" else cx + 20
        ax.add_line(Line2D([actor_xy[0], ex], [actor_xy[1], cy], color=GREY, lw=0.9, zorder=1, alpha=0.8))

    AL1 = (11.6, 70); AL2 = (11.6, 40)  # admin, entrenador (right shoulder)
    AR1 = (88.4, 66); AR2 = (88.4, 36)  # jugador, familiar (left shoulder)

    # Admin: everything administrative
    for t in ["Gestionar usuarios y roles", "Gestionar equipos y generarlos\nautomáticamente",
              "Crear y gestionar competiciones", "Publicar en blog y tablón",
              "Exportar clasificación por estaciones a Excel", "Autenticarse / gestionar perfil"]:
        link(AL1, t, "L")
    # Entrenador
    for t in ["Registrar resultados de partidos", "Gestionar competiciones de siesta",
              "Exportar clasificación de siesta a PDF", "Crear y gestionar competiciones",
              "Autenticarse / gestionar perfil"]:
        link(AL2, t, "L")
    # Jugador / premium
    for t in ["Autenticarse / gestionar perfil", "Consultar clasificaciones y estadísticas",
              "Recibir notificaciones push", "Gestionar competiciones de siesta"]:
        link(AR1, t, "R")
    # Familiar / visitante
    for t in ["Consultar clasificaciones y estadísticas", "Recibir notificaciones push"]:
        link(AR2, t, "R")

    save(fig, "casos_uso.png")


# ===========================================================================
# 4) NAVEGACION (go_router)
# ===========================================================================
def navegacion():
    fig, ax = newfig(13, 8.5)
    ax.text(50, 97, "Mapa de navegación (rutas de go_router)", ha="center",
            va="center", fontsize=12.5, fontweight="bold", color=PRIMARY)

    box(ax, 38, 84, 24, 8, "/login  ·  /register\n(Autenticación)", fc=ACCENT_L, ec=ACCENT, fs=8.5, fw="bold", tc="#E65100")
    box(ax, 41, 68, 18, 8, "/  (Home)", fc=PRIMARY, ec=PRIMARY_D, fs=10, fw="bold", tc="white")
    arrow(ax, (50, 84), (50, 76), color=ACCENT)

    nodes = [
        (2, 50, "/standings\nClasificación"),
        (16.5, 50, "/add-score\nAñadir punt."),
        (31, 50, "/competitions\n/manage"),
        (45.5, 50, "/blog\n· detail · edit"),
        (60, 50, "/tablon\nAnuncios"),
        (74.5, 50, "/veladas\nRanking"),
        (88.5, 50, "/trainings\nEntren."),
    ]
    for (x, y, t) in nodes:
        box(ax, x, y, 12.5, 9, t, fc=LIGHT, ec=PRIMARY, fs=7.3)
        arrow(ax, (50, 68), (x + 6.25, y + 9), color=MED, lw=1.1)

    # siesta subtree
    box(ax, 33, 30, 16, 8, "/siesta\n(Home)", fc="#F3E5F5", ec=PRIMARY, fs=8.5, fw="bold")
    arrow(ax, (50, 68), (41, 38), color=MED, lw=1.1)
    sies = [
        (4, 14, "/siesta/create"),
        (20, 14, "/siesta/league/:id"),
        (37, 14, "/siesta/daily/:id"),
        (54, 14, "/siesta/freethrows/:id"),
        (71, 14, "/siesta/participant/…"),
    ]
    for (x, y, t) in sies:
        box(ax, x, y, 15, 7.5, t, fc=ACCENT_L, ec=ACCENT, fs=6.8, tc="#E65100")
        arrow(ax, (41, 30), (x + 7.5, y + 7.5), color=ACCENT, lw=1.0)

    # admin subtree
    box(ax, 80, 30, 17, 8, "/admin\ndashboard · users\ngroups · veladas", fc=GREEN_L, ec=GREEN, fs=7.2, fw="bold", tc="#1B5E20")
    arrow(ax, (50, 68), (88, 38), color=MED, lw=1.1)

    box(ax, 2, 30, 14, 7, "/profile", fc=LIGHT, ec=PRIMARY, fs=8)
    arrow(ax, (50, 68), (9, 37), color=MED, lw=1.1)
    box(ax, 18, 30, 12, 7, "/stats", fc=LIGHT, ec=PRIMARY, fs=8)
    arrow(ax, (50, 68), (24, 37), color=MED, lw=1.1)

    ax.text(50, 3, "Las rutas con guard de autenticación redirigen a /login si no hay sesión activa.",
            ha="center", va="center", fontsize=7.6, color=GREY, fontstyle="italic")
    save(fig, "navegacion.png")


# ===========================================================================
# 5) DESPLIEGUE
# ===========================================================================
def despliegue():
    fig, ax = newfig(11, 8.5)
    ax.text(50, 97, "Diagrama de despliegue", ha="center", va="center",
            fontsize=12.5, fontweight="bold", color=PRIMARY)

    # clients
    box(ax, 6, 78, 88, 13, "", fc="#FAF7FF", ec=PRIMARY, lw=1.5)
    ax.text(50, 88.5, "DISPOSITIVOS CLIENTE", ha="center", fontsize=9.5, fontweight="bold", color=PRIMARY_D)
    box(ax, 12, 79.5, 22, 6.5, "Android\n(APK nativa)", fc=GREEN_L, ec=GREEN, fs=8.5, fw="bold", tc="#1B5E20")
    box(ax, 39, 79.5, 22, 6.5, "iOS\n(app nativa)", fc=BLUE_L, ec=BLUE, fs=8.5, fw="bold", tc="#0D47A1")
    box(ax, 66, 79.5, 22, 6.5, "Navegador web\n(PWA)", fc=ACCENT_L, ec=ACCENT, fs=8.5, fw="bold", tc="#E65100")

    # hosting
    box(ax, 30, 58, 40, 9, "Firebase Hosting\nDistribución de la PWA (build/web)", fc=LIGHT, ec=PRIMARY, fs=9, fw="bold")
    arrow(ax, (77, 79.5), (60, 67), color=ACCENT)

    # backend services
    box(ax, 6, 30, 26, 14, "Supabase\n\nPostgreSQL\nAuth · Realtime\nRow Level Security",
        fc=GREEN_L, ec=GREEN, fs=8.6, fw="bold", tc="#1B5E20")
    box(ax, 37, 30, 26, 14, "Firebase\nCloud Messaging\n\nNotificaciones\npush (FCM)",
        fc=ACCENT_L, ec=ACCENT, fs=8.6, fw="bold", tc="#E65100")
    box(ax, 68, 30, 26, 14, "Cloudinary\n\nAlmacenamiento y\nentrega de\nimágenes",
        fc=BLUE_L, ec=BLUE, fs=8.6, fw="bold", tc="#0D47A1")

    # arrows clients -> services (HTTPS / WSS)
    for cx in [23, 50, 77]:
        arrow(ax, (cx, 79.5), (19, 44), color=GREEN, lw=1.2)
        arrow(ax, (cx, 79.5), (50, 44), color=ACCENT, lw=1.2)
        arrow(ax, (cx, 79.5), (81, 44), color=BLUE, lw=1.2)

    ax.text(50, 22, "Comunicación mediante HTTPS y WebSockets (tiempo real con Supabase Realtime)",
            ha="center", va="center", fontsize=8, color=GREY, fontstyle="italic")
    ax.text(50, 17, "Una única base de código Flutter compila para las tres plataformas.",
            ha="center", va="center", fontsize=8, color=GREY, fontstyle="italic")
    save(fig, "despliegue.png")


if __name__ == "__main__":
    arquitectura()
    modelo_datos()
    casos_uso()
    navegacion()
    despliegue()
    print("TODOS LOS DIAGRAMAS GENERADOS")
