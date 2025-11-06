#include "pool.h"
#include <QCoreApplication>
#include <QFile>
#include <QHash>
#include <QByteArray>
#include <QtDebug>
#include <QRandomGenerator>
#include <QQuickItem>

Pool::Pool(QQuickItem *parent)
    : QQuickItem{parent}
{


    loadNumbers();
    currentIndex = 0;
}

void Pool::loadNumbers() {
    QFile file(":/random_numbers.txt"); // Assuming the resource file is added as a Qt resource
    if (file.open(QIODevice::ReadOnly)) {
        QString byteArray = QString::fromLocal8Bit(file.readAll());
        QStringList colors;
        colors << byteArray.split("");
        file.close();

        for (int i = 0; i < colors.count(); ++i) {
            int number = colors.at(i).toInt();
            if (number < 4)  {
                m_numbers[i] = number;
            //       qDebug() << "Pool Color:" << i <<  m_numbers.value(i);
            }
        }
    } else {
        qDebug() << "Error opening the file.";
    }
}

int Pool::randomNumber()
{

    int current_index = getCurrentIndex();

    if (m_numbers.keys().contains(current_index + 1)) {
        setCurrentIndex(current_index + 1);
    } else {
        setCurrentIndex(0);
    }
    return m_numbers.value(getCurrentIndex(), 0);
}

QString Pool::nextColor()
{
    QStringList colors;
    colors << "red" << "blue" << "yellow" << "green";
    int randomNum;
    int current_index = getCurrentIndex();

    randomNum = randomNumber();

    if ((randomNum >= 0) && (randomNum < colors.length())) {
        return colors.at(randomNum);
    } else {
        return "black";
    }
}




