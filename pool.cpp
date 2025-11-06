#include "pool.h"
#include <QCoreApplication>
#include <QFile>
#include <QHash>
#include <QByteArray>
#include <QDebug>


Pool::Pool(QObject *parent)
    : QObject{parent}
{


    loadNumbers();
}

void Pool::loadNumbers() {
    QFile file(":/random_numbers.txt"); // Assuming the resource file is added as a Qt resource
    if (file.open(QIODevice::ReadOnly)) {
        QString byteArray = QString::fromLocal8Bit(file.readAll());
        QStringList colors;
        colors << byteArray.split("");
        file.close();

        for (int i = 0; i < colors.size(); ++i) {
            int number = colors.at(i).toInt();
            if (number < 4)  {
                m_numbers[i] = number;
                //   qDebug() << "Pool Color:" << i <<  m_numbers.value(i);
            }
        }
    } else {
        qDebug() << "Error opening the file.";
    }
}

int Pool::randomNumber(int current_index, int queueNum)
{

    if (current_index != -1) {
        this->m_poolQueueIndexes[queueNum]  = current_index;
    }
    if (m_numbers.keys().contains(current_index + 1)) {
        this->m_poolQueueIndexes[queueNum]  = current_index + 1;
    } else {
        this->m_poolQueueIndexes[queueNum]  = 0;
    }
    return m_numbers.value(m_poolQueueIndexes.value(queueNum, 0), 0);
}

QString Pool::nextColor(int current_index, int queueNum)
{
    QStringList colors;
    colors << "red" << "blue" << "yellow" << "green";
    int randomNum = randomNumber(current_index, queueNum);
    if ((randomNum >= 0) && (randomNum < colors.length())) {
        return colors.at(randomNum);
    } else {
        return "black";
    }
}
