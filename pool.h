#ifndef POOL_H
#define POOL_H

#include <QObject>
#include <QHash>

class Pool : public QObject
{
    Q_OBJECT
public:
    explicit Pool(QObject *parent = nullptr);

    void loadNumbers();
    QHash<int, int> m_numbers;
    int pool_index;
   Q_INVOKABLE int randomNumber(int current_index = -1, int queueNum = 0);
    Q_INVOKABLE QString nextColor(int current_index = -1, int queueNum = 0);
   QHash<int, int> m_poolQueueIndexes;
signals:

};

#endif // POOL_H
