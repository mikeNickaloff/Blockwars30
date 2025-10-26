#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QResource>
#include "pool.h"
#include <QDir>
int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    const QString rccPath = QDir(QCoreApplication::applicationDirPath()).filePath("images.rcc");
    QResource::registerResource(rccPath);



    QQmlApplicationEngine engine;
    qmlRegisterType<Pool>("com.blockwars", 1, 0, "Pool");
    engine.addImportPath("qrc:///");         //
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);
    engine.loadFromModule("Blockwars30", "Main");

    return app.exec();
}
