# Hitobito Bienenschweiz

This hitobito wagon defines the organization hierarchy with groups and roles
of Bienenschweiz.


## Bienenschweiz Organization Hierarchy

<!-- roles:start -->
(Output of rake app:hitobito:roles)
* Dachverband
  * Dachverband
    * Administrator BienenSchweiz: [:admin, :layer_and_below_full]
  * Mitglieder
    * Ehrenmitglied: [:contact_data]
    * Ehrenpräsident: [:contact_data]
    * Andere Mitglieder: []
  * Zentralvorstand
    * Präsident: [:contact_data, :layer_and_below_read]
    * Vizepräsident: [:contact_data, :layer_and_below_read]
    * Finanzen: [:contact_data, :layer_and_below_read]
    * Beisitzer: [:contact_data, :layer_and_below_read]
  * Shop
    * Kunde: []
  * BienenZeitung
    * Abo: []
  * ThemenbezogeneKontakte
    * Händler: []
    * Inserenten: []
    * Mitarbeitende: [:layer_and_below_read]
    * Supervisor: [:layer_and_below_read]
* Kantonalverband < Dachverband
  * Kantonalverband
    * AdminKanton: [:layer_full]
  * Administrator
    * Kontakte: [:layer_full]
    * Veranstaltungen/Kurse: [:layer_full]
  * Vorstand
    * Bildung: [:contact_data, :layer_and_below_read]
    * Produkte: [:contact_data, :layer_and_below_read]
    * Zucht: [:contact_data, :layer_and_below_read]
    * Präsident/in: [:contact_data, :layer_and_below_read]
    * Vizepräsident/in: [:contact_data, :layer_and_below_read]
    * Kassier/in: [:contact_data, :layer_and_below_read]
    * Aktuar/in: [:contact_data, :layer_and_below_read]
    * Beisitzer/in: [:contact_data, :layer_and_below_read]
* Sektion < Kantonalverband
  * Sektion
    * Admin Sektion: [:layer_and_below_full]
  * Siegelimker/in
    * Siegelimker/in: [:layer_read]
  * Administrator
    * Erfassung Veranstaltungen: []
    * Kontakte: []
  * Mitglieder
    * Ehrenmitglied: []
    * Freimitglied: []
    * Veteranen: []
    * Mitglied: []
  * Vorstand
    * Bildung: [:contact_data, :layer_and_below_read]
    * Produkte: [:contact_data, :layer_and_below_read]
    * Zucht: [:contact_data, :layer_and_below_read]
    * Präsident/in: [:contact_data, :layer_and_below_read]
    * Vizepräsident/in: [:contact_data, :layer_and_below_read]
    * Kassier/in: [:contact_data, :layer_and_below_read]
    * Aktuar/in: [:contact_data, :layer_and_below_read]
    * Beisitzer/in: [:contact_data, :layer_and_below_read]
  * Kader
    * Fachperson Bildung: [:contact_data, :layer_read]
    * Fachperson Produkte: [:contact_data, :layer_read]
    * Fachperson Zucht & Vermehrung: [:contact_data, :layer_read]
<!-- roles:end -->
