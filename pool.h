#ifndef POOL_H
#define POOL_H

#include <QObject>
#include <QHash>
#include <QQuickItem>

class Pool : public QQuickItem
{
    Q_OBJECT
    Q_PROPERTY (int currentIndex READ getCurrentIndex WRITE setCurrentIndex NOTIFY currentIndexChanged)
public:

    explicit Pool(QQuickItem *parent = nullptr);

    void loadNumbers();
    QHash<int, int> m_numbers;
    int pool_index;
   Q_INVOKABLE int randomNumber();
    Q_INVOKABLE QString nextColor();
    int currentIndex;
   int getCurrentIndex() { return currentIndex; }
    Q_INVOKABLE QString colorAt(int idx)  {
        int val = m_numbers.value(idx);
        QStringList colors;
        colors << "red" << "blue" << "yellow" << "green";
        return colors.at(val);
    }
public slots:
    Q_INVOKABLE void setCurrentIndex(int _currentIndex) { this->currentIndex = _currentIndex; emit this->currentIndexChanged(this->currentIndex); qDebug() << "Index Changed" << this->currentIndex; }


signals:
    void currentIndexChanged(int new_val);
};

#endif // POOL_H
