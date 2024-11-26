require_relative 'metres_collect2XML' 
require 'rexml/document'
require 'json'


require_relative 'metres_face_extraction'
require_relative 'metres_calculations_export'

module Guisse
  module PEBExpress
    @dialog_metres = nil
    @face_infos = {}
    @unites_infos = {}
    @fused_faces_infos = {}

    class << self

      #EXCEL_FILE_PATH = "C:/Users/JGU/Documents/Progra/Extension Sketch Up/PEB Express/extract_info_results.csv"
      #XML_FILE_PATH = "C:/Users/JGU/Documents/Progra/Extension Sketch Up/PEB Express/generated_xml.xml"

      def main
        model = Sketchup.active_model
        selection = model.selection
        
        @face_infos = {}
        @unites_infos = {}
        # Nouveau hash pour tracker les noms utilisés
        parent_names_count = Hash.new(0)
        duplicate_names = []

        Sketchup.status_text = "Extraction des informations en cours..."
        
        selection.each do |entity|
          case entity
          when Sketchup::Face
            @face_infos[entity.entityID] = get_face_info(entity, "Selection Directe", Geom::Transformation.new)
          when Sketchup::Group
            sub_entities = entity.entities
            parent_name = entity.name.empty? ? "Sans Nom" : entity.name
            # Incrémenter le compteur pour ce nom
            parent_names_count[parent_name] += 1
            # Si c'est la deuxième occurrence, ajouter à la liste des doublons
            if parent_names_count[parent_name] == 2
              duplicate_names << parent_name
            end
            @unites_infos[entity.entityID] = get_group_volumes(entity, parent_name)
            @face_infos.merge!(process_entities(sub_entities, parent_name, entity.transformation))
            # Charger le commentaire sauvegardé
            @unites_infos[entity.entityID][:comment] = entity.get_attribute('PEBExpress', 'comment', '')
          when Sketchup::ComponentInstance
            sub_entities = entity.definition.entities
            parent_name = entity.definition.name.empty? ? "Sans Nom" : entity.definition.name
            # Incrémenter le compteur pour ce nom
            parent_names_count[parent_name] += 1
            # Si c'est la deuxième occurrence, ajouter à la liste des doublons
            if parent_names_count[parent_name] == 2
              duplicate_names << parent_name
            end
            @unites_infos[entity.entityID] = get_group_volumes(entity, parent_name)
            @face_infos.merge!(process_entities(sub_entities, parent_name, entity.transformation))
            # Charger le commentaire sauvegardé
            @unites_infos[entity.entityID][:comment] = entity.definition.get_attribute('PEBExpress', 'comment', '')
          end
        end

        find_adjacent_faces(@face_infos)

        @face_infos = sort_face_infos(@face_infos)
        @unites_infos = @unites_infos.sort_by { |_, unite_info| unite_info[:name] }
        @fused_faces_infos = fuse_faces(@face_infos)

        @unites_infos.each do |entity_id, unite_info|
          results = calculate_ath_and_ratios(@face_infos, unite_info[:name])
          unite_info.merge!(results)
          entity = model.entities.find { |e| e.entityID == entity_id }
          if entity
            custom_ach = get_custom_ach(entity)
            if custom_ach
              unite_info[:surface_ach] = custom_ach
              puts "Valeur Ach personnalisée chargée pour l'entité #{entity_id}: #{custom_ach}"
            else
              puts "Pas de valeur Ach personnalisée pour l'entité #{entity_id}"
            end
          end
        end

        #export_to_csv(@face_infos, @unites_infos, @fused_faces_infos, EXCEL_FILE_PATH)
        #convert_to_xml(@fused_faces_infos, @unites_infos, XML_FILE_PATH)

        Sketchup.status_text = "Extraction terminée."

        # Structurer les données par groupe
        grouped_faces = @fused_faces_infos.values.group_by { |face| face["Groupe"] }

        # Inclure les informations des unités dans les données envoyées au dialogue HTML
        data = {
          grouped_faces: grouped_faces,
          unites_infos: @unites_infos.map do |entity_id, info|
            warnings = []
            moderate_warnings = []
            
            warnings << "Le volume de cette unité est nul ou négatif." if info[:volume] <= 0
            warnings << "La surface de cette unité est nulle ou négative." if info[:surface_ach] <= 0
            

            if info[:surface_ach] > 0
              moderate_warnings << "Attention hauteur sous plafond inférieure à 2,5 m (valeur réelle = #{(info[:volume]/info[:surface_ach]).round(2)})" if info[:volume]/info[:surface_ach] <= 2.5
              moderate_warnings << "Attention hauteur sous plafond supérieure à 10 m (valeur réelle = #{(info[:volume]/info[:surface_ach]).round(2)})" if info[:volume]/info[:surface_ach] > 10
            end

            # Récupérer l'entité correspondante
            entity = Sketchup.active_model.entities.find { |e| e.entityID == entity_id }
            
            # Récupérer la valeur Ach personnalisée si elle existe
            custom_ach = get_custom_ach(entity) if entity
            
            # Utiliser la valeur Ach personnalisée si elle existe, sinon utiliser la valeur calculée
            surface_ach = custom_ach || info[:surface_ach]
            
            info.merge(
              entityId: entity_id,
              warnings: warnings,
              moderateWarnings: moderate_warnings,
              surface_ach: surface_ach,
              ach_modified: !custom_ach.nil?  # Garder cet indicateur
            )
          end
        }

        # Vérifier si la boîte de dialogue existe et est visible
        if @dialog_metres && @dialog_metres.visible?
          @dialog_metres.execute_script("populateTables(#{data.to_json})")
        else
          show_html_dialog(data)
        end

        # Afficher l'alerte si des noms en double ont été trouvés
        unless duplicate_names.empty?
          message = "ATTENTION : Les noms suivants sont utilisés plusieurs fois :\n"
          message += duplicate_names.join("\n")
          message += "\nCela pourrait causer des erreurs dans le traitement ultérieur (toutes les parois sont fusionnées dans un et un seul groupe)."
          UI.messagebox(message, MB_OK)
        end

        Sketchup.status_text = "Extraction terminée."
      end

      def show_html_dialog(data)
        
        @dialog_metres = UI::HtmlDialog.new(
          {
            :dialog_title => "Métrés PEB",
            :preferences_key => "com.sample.plugin",
            :scrollable => true,
            :resizable => true,
            :width => 800,
            :height => 700,
            :style => UI::HtmlDialog::STYLE_DIALOG
          }
        )

        html_path = File.join(__dir__, '../html/metres_dialog.html')
        @dialog_metres.set_file(html_path)

        @dialog_metres.add_action_callback("refreshData") do |action_context|
          main
        end

        @dialog_metres.add_action_callback("exportExcel") do |action_context|
          export_excel
        end

        @dialog_metres.add_action_callback("exportXML") do |action_context|
          export_xml
        end

        @dialog_metres.add_action_callback("ready") do |action_context|
          @dialog_metres.execute_script("populateTables(#{data.to_json})")
        end

        @dialog_metres.add_action_callback("saveComment") do |action_context, params|
          puts "Action callback 'saveComment' appelée avec params: #{params}"
          entity_id, comment = params.split('|||')
          puts "entity_id décodé: #{entity_id}, comment décodé: #{comment}"
          save_comment(entity_id, comment)
        end

        @dialog_metres.add_action_callback("saveAch") do |action_context, params|
          puts "Action callback 'saveAch' appelée avec params: #{params}"
          entity_id, ach_value = params.split('|||')
          puts "entity_id décodé: #{entity_id}, ach_value décodée: #{ach_value}"
          save_ach(entity_id, ach_value.to_f)
        end

        @dialog_metres.add_action_callback("resetAch") do |action_context, params|
          puts "Action callback 'resetAch' appelée avec params: #{params}"
          entity_id, ach_value = params.split('|||')
          puts "entity_id décodé: #{entity_id}, ach_value décodée: #{ach_value}"
          reset_ach(entity_id)
        end

        @dialog_metres.show
      end

      def export_excel
        filepath1 = UI.savepanel("Enregistrer les fichiers Excels générés", "~", "excel_genere.csv")
        return unless filepath1
        filepath1 += ".csv" unless filepath1.end_with?(".csv")

        # Export des données originales
        export_to_csv(@face_infos, @unites_infos, @fused_faces_infos, filepath1)

        UI.messagebox("Fichiers Excel générés et sauvegardés avec succès!")
      end

      def export_xml
        filepath = UI.savepanel("Enregistrer le fichier XML généré", "~", "xml_genere.xml")
        return unless filepath
        filepath += ".xml" unless filepath.end_with?(".xml")

        # Export des données en XML
        convert_to_xml(@fused_faces_infos, @unites_infos, filepath)

        UI.messagebox("Fichier XML généré et sauvegardé avec succès!")
      end

      def save_comment(entity_id, comment)
        puts "Début de save_comment avec entity_id: #{entity_id}, comment: #{comment}"
        model = Sketchup.active_model
        entity = model.entities.find { |e| e.entityID.to_s == entity_id.to_s }
        
        if entity
          puts "Entité trouvée. Type: #{entity.class}"
          if entity.is_a?(Sketchup::ComponentInstance)
            entity.definition.set_attribute('PEBExpress', 'comment', comment)
            puts "Commentaire sauvegardé pour la définition du composant: #{entity.definition.name}"
          elsif entity.is_a?(Sketchup::Group)
            entity.set_attribute('PEBExpress', 'comment', comment)
            puts "Commentaire sauvegardé pour le groupe: #{entity.name}"
          else
            puts "Entité non valide pour la sauvegarde du commentaire. Type d'entité: #{entity.class}"
            return
          end
          
          update_unites_infos(entity, comment)
          update_dialog_data
          
          # Appel de la fonction JavaScript pour mettre à jour l'UI
          js_command = "updateCommentUI('#{entity_id}', '#{comment.gsub("'", "\\\\'")}');"
          puts "Exécution de la commande JS: #{js_command}"
          @dialog_metres.execute_script(js_command)
          
          puts "Commentaire sauvegardé et mise à jour de l'UI demandée"
        else
          puts "Entité non trouvée pour la sauvegarde du commentaire. ID: #{entity_id}"
        end
      end

      def get_comment(entity)
        if entity.is_a?(Sketchup::ComponentInstance)
          entity.definition.get_attribute('PEBExpress', 'comment', '')
        elsif entity.is_a?(Sketchup::Group)
          entity.get_attribute('PEBExpress', 'comment', '')
        else
          ''
        end
      end
      
      def save_ach(entity_id, ach_value)
        puts "Début de save_ach avec entity_id: #{entity_id}, ach_value: #{ach_value}"
        model = Sketchup.active_model
        entity = model.entities.find { |e| e.entityID.to_s == entity_id.to_s }
        
        if entity
          puts "Entité trouvée. Type: #{entity.class}"
          if entity.is_a?(Sketchup::ComponentInstance)
            entity.definition.set_attribute('PEBExpress', 'custom_ach', ach_value)
            puts "Valeur Ach sauvegardée pour le composant: #{entity.definition.name}, valeur: #{ach_value}"
          elsif entity.is_a?(Sketchup::Group)
            entity.set_attribute('PEBExpress', 'custom_ach', ach_value)
            puts "Valeur Ach sauvegardée pour le groupe: #{entity.name}, valeur: #{ach_value}"
          else
            puts "Entité non valide pour la sauvegarde de la valeur Ach. Type d'entité: #{entity.class}"
            return
          end
          
          update_unites_infos_ach(entity, ach_value)
          
          # Appel de la fonction JavaScript pour mettre à jour l'UI
          js_command = "updateAchFromSketchUp('#{entity_id}', #{ach_value});"
          puts "Exécution de la commande JS: #{js_command}"
          @dialog_metres.execute_script(js_command)
          
          puts "Valeur Ach sauvegardée et mise à jour de l'UI demandée"
        else
          puts "Entité non trouvée pour la sauvegarde de la valeur Ach. ID: #{entity_id}"
        end
      end

      def get_custom_ach(entity)
        value = if entity.is_a?(Sketchup::ComponentInstance)
          entity.definition.get_attribute('PEBExpress', 'custom_ach', nil)
        elsif entity.is_a?(Sketchup::Group)
          entity.get_attribute('PEBExpress', 'custom_ach', nil)
        end
        puts "get_custom_ach pour l'entité #{entity.entityID}: #{value}"
        value
      end

      def update_unites_infos(entity, comment)
        puts "Mise à jour de unites_infos pour l'entité ID: #{entity.entityID}"
        if @unites_infos[entity.entityID]
          @unites_infos[entity.entityID][:comment] = comment
          puts "unites_infos mis à jour avec le nouveau commentaire"
        else
          puts "Aucune entrée trouvée dans unites_infos pour cette entité"
        end
      end

      def update_unites_infos_ach(entity, ach_value)
        puts "Mise à jour de unites_infos pour l'entité ID: #{entity.entityID}"
        if @unites_infos[entity.entityID]
          @unites_infos[entity.entityID][:surface_ach] = ach_value
          puts "unites_infos mis à jour avec la nouvelle valeur Ach"
        else
          puts "Aucune entrée trouvée dans unites_infos pour cette entité"
        end
      end

      def reset_ach(entity_id)
        puts "Début de reset_ach avec entity_id: #{entity_id}"
        model = Sketchup.active_model
        entity = model.entities.find { |e| e.entityID.to_s == entity_id.to_s }
        
        if entity
          if entity.is_a?(Sketchup::ComponentInstance)
            entity.definition.delete_attribute('PEBExpress', 'custom_ach')
            puts "Valeur Ach supprimée pour le composant: #{entity.definition.name}"
          elsif entity.is_a?(Sketchup::Group)
            entity.delete_attribute('PEBExpress', 'custom_ach')
            puts "Valeur Ach supprimée pour le groupe: #{entity.name}"
          else
            puts "Entité non valide pour la réinitialisation de la valeur Ach. Type d'entité: #{entity.class}"
            return
          end
          
          update_unites_infos_ach(entity, nil)
          
          # Appel de la fonction JavaScript pour mettre à jour l'UI
          js_command = "updateAchFromSketchUp('#{entity_id}', null);"
          puts "Exécution de la commande JS: #{js_command}"
          @dialog_metres.execute_script(js_command)
          
          puts "Valeur Ach réinitialisée et mise à jour de l'UI demandée"
        else
          puts "Entité non trouvée pour la réinitialisation de la valeur Ach. ID: #{entity_id}"
        end
      end
      

      def update_dialog_data
        puts "Début de update_dialog_data"
        data = {
          grouped_faces: @fused_faces_infos.values.group_by { |face| face["Groupe"] },
          unites_infos: @unites_infos.map do |entity_id, info|
            entity = Sketchup.active_model.entities.find { |e| e.entityID == entity_id }
            if entity
              custom_ach = get_custom_ach(entity)
              info[:surface_ach] = custom_ach if custom_ach
              comment = get_comment(entity)
              warnings = []
              moderate_warnings = []
              
              warnings << "Le volume de cette unité est nul ou négatif." if info[:volume] <= 0
              warnings << "La surface de cette unité est nulle ou négative." if info[:surface_ach] <= 0
              
              if info[:surface_ach] > 0
                moderate_warnings << "Attention hauteur sous plafond inférieure à 2,5 m (valeur réelle = #{(info[:volume]/info[:surface_ach]).round(2)})" if info[:volume]/info[:surface_ach] <= 2.5
                moderate_warnings << "Attention hauteur sous plafond supérieure à 10 m (valeur réelle = #{(info[:volume]/info[:surface_ach]).round(2)})" if info[:volume]/info[:surface_ach] > 10
              end

              puts "Mise à jour des données pour l'entité ID: #{entity_id}, Type: #{entity.class}, Commentaire: #{comment}"
              info.merge(
                entityId: entity_id,
                comment: comment,
                warnings: warnings,
                moderateWarnings: moderate_warnings
              )
            else
              puts "Entité non trouvée pour ID: #{entity_id}"
              info
            end
          end
        }
        js_command = "populateTables(#{data.to_json});"
        # puts "Exécution du script JavaScript pour mettre à jour le dialogue: #{js_command}"
        @dialog_metres.execute_script(js_command)
        puts "Fin de update_dialog_data"
      end

      def create_toolbar
        toolbar = UI::Toolbar.new "Métrés PEB"

        cmd = UI::Command.new("Métrés PEB") {
          if @dialog_metres && @dialog_metres.visible?
            @dialog_metres.bring_to_front
          else
            main
          end
        }
        cmd.small_icon = File.join(__dir__, '../images/metres_small_icon.png')
        cmd.large_icon = File.join(__dir__, '../images/metres_large_icon.png')
        cmd.tooltip = "Métrés PEB"
        cmd.status_bar_text = "Afficher les métrés et exporter les données"
        cmd.menu_text = "Afficher métrés"
        toolbar = toolbar.add_item cmd

        toolbar.show
      end
    end
  end

  PEBExpress.create_toolbar

end
