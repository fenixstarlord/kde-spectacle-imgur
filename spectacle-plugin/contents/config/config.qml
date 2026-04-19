import QtQuick
import QtQuick.Controls

Item {
    width: 500
    height: 140

    Column {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 8

        Label {
            text: "This plugin is configured through environment variables."
            wrapMode: Text.WordWrap
        }

        Label {
            text: "Set SPECTACLE_PLUGIN_PROVIDER, SPECTACLE_PLUGIN_IMGUR_CLIENT_ID, and related variables before launching Spectacle."
            wrapMode: Text.WordWrap
        }
    }
}
