#include <QApplication>
#include <QQuickWindow>
#include <QtTest>
#include <Plasma/Applet>
#include <Plasma/Corona>
#include <Plasma/Containment>
#include <KPackage/PackageLoader>
#include <KPackage/Package>
#include <Plasma/PluginLoader>
#include <PlasmaQuick/AppletQuickItem>
#include <cstdio>
class TestCorona : public Plasma::Corona { public: using Plasma::Corona::createContainmentDelayed; QRect screenGeometry(int) const override { return QRect(0,0,1000,1000); } };
int main(int argc, char **argv) {
    QApplication app(argc, argv);
    TestCorona corona;
    auto shell = KPackage::PackageLoader::self()->loadPackage("Plasma/Shell");
    shell.setPath("org.kde.plasma.desktop");
    corona.setKPackage(shell);
    auto *containment = corona.createContainmentDelayed("org.kde.plasma.systemtray");
    if (!containment) return 9;
    QStringList known;
    for (const auto &m : Plasma::PluginLoader::self()->listAppletMetaData(QString())) known << m.pluginId();
    auto config = containment->config().group("General");
    config.writeEntry("knownItems", known);
    config.writeEntry("extraItems", QStringList{"org.dralk.aurorasleep"});
    config.writeEntry("shownItems", QStringList{"org.dralk.aurorasleep"});
    containment->setLocation(Plasma::Types::BottomEdge);
    containment->setFormFactor(Plasma::Types::Horizontal);
    containment->init();
    auto rootConfig = containment->config();
    containment->restore(rootConfig);
    QQuickWindow window;
    auto *trayItem = PlasmaQuick::AppletQuickItem::itemForApplet(containment);
    trayItem->setParentItem(window.contentItem());
    trayItem->setSize(QSizeF(600,48));
    window.resize(600,48);
    window.show();
    QTest::qWait(300);
    Plasma::Applet *applet = nullptr;
    for (auto a : containment->applets()) if (a->pluginMetaData().pluginId() == "org.dralk.aurorasleep") applet = a;
    if (!applet) { fprintf(stderr,"Aurora wasn't added to the real tray\n"); return 10; }
    auto *item = PlasmaQuick::AppletQuickItem::itemForApplet(applet);
    if (item->preferredRepresentation() != nullptr) return 3;
    if (!item->compactRepresentationItem()) return 4;
    auto state = trayItem->property("systemTrayState").value<QObject*>();
    fprintf(stdout,"Tray item: %s; Aurora size: %.1f x %.1f; state: %p; expanded before: %d\n",qPrintable(trayItem->objectName()),item->width(),item->height(),state,item->isExpanded());
    QSignalSpy spy(item, &PlasmaQuick::AppletQuickItem::expandedChanged);
    QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, item->mapToScene(QPointF(item->width()/2,item->height()/2)).toPoint());
    QTest::qWait(200);
    fprintf(stdout,"After click: Aurora expanded %d, tray expanded %d, signal count %lld\n",item->isExpanded(),state ? state->property("expanded").toBool() : -1,(long long)spy.count());
    if (!item->isExpanded() || spy.count() != 1 || !item->fullRepresentationItem() || !state || !state->property("expanded").toBool()) return 5;
    QTest::mouseClick(&window, Qt::LeftButton, Qt::NoModifier, item->mapToScene(QPointF(item->width()/2,item->height()/2)).toPoint());
    QTest::qWait(100);
    if (item->isExpanded() || spy.count() != 2 || state->property("expanded").toBool()) return 6;
    fprintf(stdout, "Native system tray: popup opens on first click and closes on second click.\n");
    return 0;
}
