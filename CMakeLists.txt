cmake_minimum_required(VERSION 3.16)

project(Blockwars30 VERSION 0.1 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Quick)

qt_standard_project_setup(REQUIRES 6.8)

qt_add_executable(appBlockwars30
    main.cpp
)

qt_add_qml_module(appBlockwars30
    URI Blockwars30
    VERSION 1.0
    QML_FILES
        Main.qml
        QML_FILES engine/GameScene.qml
        QML_FILES engine/GameContainer.qml
        QML_FILES engine/GameLayout.qml
        QML_FILES engine/GameStaticItem.qml
        QML_FILES engine/GameDynamicItem.qml
        QML_FILES engine/AbstractGameItem.qml
        QML_FILES engine/GameSpriteSheetItem.qml
        RESOURCES images.qrc
        QML_FILES game/MainMenuScene.qml
RESOURCES lib/qmldir
QML_FILES lib/promise.js lib/Promise.qml lib/PromiseTimer.qml
QML_FILES game/ui/MenuButton.qml
QML_FILES game/DebugScene.qml
SOURCES pool.h pool.cpp
QML_FILES engine/GameDragItem.qml
QML_FILES engine/GameDragAndSwapItem.qml engine/GameDropItem.qml
RESOURCES AGENTS.md WHEEL.md TODO.md CHANGES.md
)

# Qt for iOS sets MACOSX_BUNDLE_GUI_IDENTIFIER automatically since Qt 6.1.
# If you are developing for iOS or macOS you should consider setting an
# explicit, fixed bundle identifier manually though.
set_target_properties(appBlockwars30 PROPERTIES
#    MACOSX_BUNDLE_GUI_IDENTIFIER com.example.appBlockwars30
    MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
    MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION_MAJOR}.${PROJECT_VERSION_MINOR}
    MACOSX_BUNDLE TRUE
    WIN32_EXECUTABLE TRUE
)

target_link_libraries(appBlockwars30
    PRIVATE Qt6::Quick
)

include(GNUInstallDirs)
install(TARGETS appBlockwars30
    BUNDLE DESTINATION .
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

add_custom_command(
  OUTPUT ${CMAKE_CURRENT_BINARY_DIR}/images.rcc
  COMMAND Qt6::rcc -binary ${CMAKE_CURRENT_SOURCE_DIR}/images.qrc
                   -o ${CMAKE_CURRENT_BINARY_DIR}/images.rcc
  DEPENDS ${CMAKE_CURRENT_SOURCE_DIR}/images.qrc
)
add_custom_target(assets_rcc ALL
  DEPENDS ${CMAKE_CURRENT_BINARY_DIR}/images.rcc)
