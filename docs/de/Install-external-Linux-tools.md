# Externe Linux-Tools installieren

**Darf ich als Administrator zusätzliche Tools auf der virtuellen Maschine von HIN Gateway installieren?**

Ja. Administratoren können zusätzliche Linux-Tools auf der virtuellen Maschine von HIN Gateway installieren, zum Beispiel für Diagnose oder Monitoring. Beachten Sie dabei die folgenden Punkte.

## Sie sind für die installierten Tools verantwortlich

HIN Gateway verwaltet und unterstützt keine Software von Drittanbietern, die auf der virtuellen Maschine installiert wird. Stellen Sie sicher, dass die zusätzlichen Tools nicht zu viel CPU, Arbeitsspeicher oder Speicherplatz belegen, damit für die Dienste von HIN Gateway genügend Ressourcen für den normalen Betrieb verfügbar bleiben.

## Installierte Tools werden bei Updates entfernt

Bei jedem Update von HIN Gateway wird die Umgebung der virtuellen Maschine ersetzt. Zusätzliche Tools werden dabei entfernt und müssen nach dem Update erneut installiert werden.

!!! tip
    Führen Sie ein kurzes Skript oder eine Liste der installierten Tools, damit Sie diese nach jedem Update schnell wieder installieren können. Details zum Update-Prozess finden Sie unter [Update und Rollback von HIN Gateway](update-hin-gateway.md).
