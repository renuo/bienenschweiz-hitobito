# Hitobito Bienenschweiz

This hitobito wagon defines the organization hierarchy with groups and roles
of Bienenschweiz.


## Bienenschweiz Organization Hierarchy

<!-- roles:start -->
* Dachverband
  * Dachverband
    * Administrator BienenSchweiz: [:admin, :layer_and_below_full]
    * Supervisor/in: [:layer_and_below_full]
  * Berater-Infos an Händler
    * Mitglied: []
  * Inspektor/in
    * Inspektor/in (kantonale Ansprechperson): []
  * Zentralvorstand
    * Zentralpräsident/in: [:contact_data]
    * Vizepräsident/in: [:contact_data]
    * Geschäftsführer/in: [:contact_data]
    * Mitglied: [:contact_data]
  * Ehrenpersonen
    * Ehrenmitglied: []
    * Ehrenpräsident: []
  * Andere Mitglieder
    * Andere Mitglieder: []
* Kantonalverband < Dachverband
  * Kantonalverband
    * Bildungsobmann/frau: [:contact_data, :layer_and_below_read]
    * Honigobmann/frau: [:contact_data, :layer_and_below_read]
    * Honigobmann/frau (provisorisch): [:layer_and_below_read]
    * Zuchtobmann/frau: [:contact_data, :layer_and_below_read]
    * Kantonalpräsident/in: [:contact_data, :layer_and_below_full]
    * Kassier/in: [:contact_data, :layer_and_below_read]
* Sektion < Kantonalverband
  * Sektion
    * Admin Sektion: [:layer_and_below_full]
    * Präsident/in: [:layer_and_below_full, :contact_data]
    * Kassier/in: [:layer_read, :contact_data]
    * Erfassung Veranstaltungen: [:layer_full]
    * Siegelimker/in: [:layer_read]
    * Siegelimker/in provisorisch: [:layer_read]
  * Bildung
    * Fachperson Bildung: [:layer_read]
    * Fachperson Bildung (in Ausbildung): [:layer_read]
  * Produkte
    * Fachperson Produkte: [:layer_read]
    * Fachperson Produkte (in Ausbildung): [:layer_read]
  * Zucht
    * Fachperson Zucht: [:layer_read]
    * Fachperson Zucht (in Ausbildung): [:layer_read]
<!-- roles:end -->
