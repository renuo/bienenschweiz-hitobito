# Hitobito Bienenschweiz

This hitobito wagon defines the organization hierarchy with groups and roles
of Bienenschweiz.


## Bienenschweiz Organization Hierarchy

<!-- roles:start -->
(Output of rake app:hitobito:roles)
* Dachverband
  * Dachverband
    * Administrator BienenSchweiz: [:admin, :layer_and_below_full, :layer_and_below_events, :impersonation]
  * Mitglieder
    * Ehrenmitglied: []
    * Ehrenpräsident: []
    * Andere Mitglieder: []
  * Zentralvorstand
    * Präsident: [:layer_and_below_read]
    * Vizepräsident: [:layer_and_below_read]
    * Finanzen: [:layer_and_below_read]
    * Beisitzer: [:layer_and_below_read]
  * Shop
    * Kunde: []
  * BienenZeitung
    * Abonnent/in: []
  * ThemenbezogeneKontakte
    * Händler: []
    * Inserenten: []
    * Supervisor: [:layer_and_below_read]
  * apiservice
    * Veranstaltungen/Kurse: [:layer_and_below_events, :layer_and_below_read]
  * Mitarbeiter/in
    * Mitarbeiter/in: []
* Kantonalverband < Dachverband
  * Kantonalverband
  * Administrator
    * Admin Kanton: [:layer_full]
    * Kontakte: [:layer_contacts, :layer_read]
    * Veranstaltungen/Kurse: [:layer_events, :layer_read]
  * Vorstand
    * Bildung: [:layer_read]
    * Produkte: [:layer_read]
    * Zucht: [:layer_read]
    * Präsident/in: [:layer_read]
    * Vizepräsident/in: [:layer_read]
    * Kassier/in: [:layer_read]
    * Aktuar/in: [:layer_read]
    * Beisitzer/in: [:layer_read]
* Sektion < Kantonalverband
  * Sektion
  * Siegelimker/in
    * Siegelimker/in: [:layer_read]
  * Administrator
    * Admin Sektion: [:layer_and_below_full]
    * Veranstaltungen/Kurse: [:layer_events, :layer_read]
    * Kontakte: [:layer_contacts, :layer_read]
  * Mitglieder
    * Ehrenmitglied: []
    * Freimitglied: []
    * Veteranen: []
    * Aktivmitglied: []
    * Passivmitglied: []
  * Vorstand
    * Bildung: [:layer_read]
    * Produkte: [:layer_read]
    * Zucht: [:layer_read]
    * Präsident/in: [:layer_read]
    * Vizepräsident/in: [:layer_read]
    * Kassier/in: [:layer_read]
    * Aktuar/in: [:layer_read]
    * Beisitzer/in: [:layer_read]
  * Kader
    * Fachperson Bildung: [:layer_read]
    * Fachperson Produkte: [:layer_read]
    * Fachperson Zucht & Vermehrung: [:layer_read]
<!-- roles:end -->
