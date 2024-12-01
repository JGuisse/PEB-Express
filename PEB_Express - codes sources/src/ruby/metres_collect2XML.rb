require 'rexml/document'
require 'set'
require 'sketchup'

module Guisse
  module PEBExpress
    @use_name_index = nil

    ESPACE_ADJACENT_DICT = {
      "EXT" => "outside",
      "EAC" => "heated-space",
      "MIT" => "heated-space",
      "EANC" => "unheated-space",
      "OPEB" => "another-unit-space",
      "MPEB" => "same-unit-space",
      "IND" => "industrial-space",
      "SOL" => "ground",
      "CAVE" => "cellar",
      "CAVES" => "cellar",
      "VV" => "crawlspace"
    }

    TYPE_PAROI_DICT = {
      "M" => "wall",
      "F" => "window",
      "PCH" => "floor-ground",
      "T" => "roof",
      "P" => "door",
      "MR" => "curtain-wall",
      "BV" => "glass-building-blocks",
      "MC" => "solar-wall",
      "L" => "dome-light",
      "PL" => "roof"
    }

    class << self 
      def get_dialog_html
        %{
          <!DOCTYPE html>
          <html lang="fr">
          <head>
            <meta charset="UTF-8">
            <title>Sélection de la méthode</title>
            <style>
              body { 
                font-family: Arial, sans-serif; 
                margin: 20px; 
                line-height: 1.6;
                background-color: #f5f5f5;
              }
              .container { 
                max-width: 500px;
                margin: 0 auto;
                background-color: white;
                padding: 20px;
                border-radius: 8px;
                box-shadow: 0 2px 4px rgba(0,0,0,0.1);
              }
              h2 {
                color: #333;
                margin-bottom: 20px;
                text-align: center;
              }
              .option {
                background-color: white;
                border: 2px solid #ddd;
                border-radius: 8px;
                padding: 15px;
                margin-bottom: 15px;
                cursor: pointer;
                transition: all 0.3s ease;
              }
              .option:hover {
                border-color: #007bff;
                background-color: #f8f9fa;
              }
              .title {
                font-weight: bold;
                font-size: 1.1em;
                color: #007bff;
                margin-bottom: 8px;
              }
              .description {
                color: #666;
                font-size: 0.9em;
              }
            </style>
          </head>
          <body>
            <div class="container">
              <h2>Choisissez la méthode de génération des index</h2>
              <div class="option" onclick="selectMethod('numeric')">
                <div class="title">Méthode numérique</div>
                <div class="description">
                  Génère des index séquentiels (01, 02, 03...) par ordre alphabétique.
                  Simple et prévisible, idéal pour une numérotation standard ou un procédé utilisant des Templates.
                </div>
              </div>
              <div class="option" onclick="selectMethod('name')">
                <div class="title">Méthode basée sur les noms des Groupes Sketch Up</div>
                <div class="description">
                  Utilise le nom des unités pour générer les index.
                  Plus descriptif et traçable, facilite l'identification des éléments.
                </div>
              </div>
            </div>
            <script>
              function selectMethod(method) {
                window.location.href = 'skp:select_method@' + method;
              }
            </script>
          </body>
          </html>
        }
      end

      def show_method_selection_dialog(&callback)
        dialog = UI::WebDialog.new(
          "Méthode de génération des index",
          false,
          "IndexMethodSelection",
          500,  # Width
          600,  # Height
          150,  # Left
          150   # Top
        )
        
        dialog.set_size(500, 600)
        dialog.set_position(150, 150)
        dialog.set_html(get_dialog_html)
        
        dialog.add_action_callback("select_method") do |dlg, method|
          @use_name_index = (method == 'name')
          dlg.close
          callback.call if callback
        end

        dialog.show_modal
      end

      def generate_index(base_name, unit_name, numero = nil)
        if @use_name_index
          # Utiliser le nom de l'unité pour générer l'index
          unit_part = index_creation(unit_name)
          "#{base_name}#{unit_part}"
        else
          # Utiliser le numéro incrémenté
          "#{base_name}#{'%02d' % numero}"
        end
      end

      def index_creation(chaine)
        # Assurez-vous que la chaîne est en UTF-8
        chaine = chaine.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
        
        # Convertir la chaîne en ASCII, supprimer les accents et les caractères non-ASCII
        nouvelle_chaine = chaine.unicode_normalize(:nfkd).encode('ASCII', invalid: :replace, undef: :replace, replace: '')
        
        # Ne garder que les caractères alphanumériques
        nouvelle_chaine = nouvelle_chaine.scan(/[a-zA-Z0-9]/).join
        
        # Si la chaîne commence par un chiffre, on ajoute "X" au début
        nouvelle_chaine = "X" + nouvelle_chaine if nouvelle_chaine[0] =~ /\d/
        
        # S'assurer que la chaîne n'est pas vide
        if nouvelle_chaine.empty?
          nouvelle_chaine = "X#{rand(100000..999999)}"
        end
        
        nouvelle_chaine
      end

      def show_error_dialog(message)
        dlg = UI::WebDialog.new("Erreur", false, "ErrorDialog", 300, 150, 150, 150, true)
        dlg.set_html("<html><body><p>#{message}</p><button onclick='window.close()'>OK</button></body></html>")
        dlg.show
      end

      def convert_to_xml(fused_faces_infos, unites_infos, xml_file_path)
        # Afficher la boîte de dialogue de sélection et attendre le choix
        show_method_selection_dialog do
          process_xml_conversion(fused_faces_infos, unites_infos, xml_file_path)
        end
      end

      def process_xml_conversion(fused_faces_infos, unites_infos, xml_file_path)
        numero_upeb = 1

        doc = REXML::Document.new
        doc << REXML::XMLDecl.new('1.0', 'UTF-8')

        project = REXML::Element.new('urn:Project')
        project.add_namespace('urn', 'urn:peb:bim')
        project.add_attributes({
          'name' => 'SketchupProject',
          'Version' => '1.0.0'
        })
        doc.add_element(project)

        project_info = REXML::Element.new('urn:ProjectInformation')
        project_info.add_attribute('xml-creation-date', Date.today.to_s)
        project.add_element(project_info)

        xsd_version = REXML::Element.new('urn:xsd-version')
        xsd_version.text = '2.0.0'
        project_info.add_element(xsd_version)

        building = REXML::Element.new('urn:Building')
        building.add_attributes({
          'name' => 'Batiment1',
          'id' => 'Batiment1'
        })
        project.add_element(building)

        protected_volume = REXML::Element.new('urn:ProtectedVolume')
        protected_volume.add_attributes({
          'name' => 'VP',
          'id' => index_creation('VP01')
        })
        building.add_element(protected_volume)

        sorted_unites_infos = unites_infos.sort_by { |_, unite_info| unite_info[:name] }

        sorted_unites_infos.each do |_, unite_info|
          process_epb_unit(protected_volume, unite_info, fused_faces_infos, numero_upeb)
          numero_upeb += 1
        end

        formatter = REXML::Formatters::Pretty.new
        formatter.compact = true
        File.open(xml_file_path, 'w') do |file|
          formatter.write(doc, file)
        end
        puts "Le fichier XML a été créé avec succès : #{xml_file_path}"
      end

      def process_epb_unit(parent, unite_info, fused_faces_infos, numero_upeb)
        epb_unit = REXML::Element.new('urn:EpbUnit')
        epb_unit.add_attributes({
          'name' => unite_info[:name],
          'id' => index_creation(generate_index("upebUnite", unite_info[:name], numero_upeb))
        })
        parent.add_element(epb_unit)

        total_surface = REXML::Element.new('urn:total-surface')
        total_surface.text = unite_info[:surface_ach].to_s
        epb_unit.add_element(total_surface)

        ventilation_zone = REXML::Element.new('urn:VentilationZone')
        ventilation_zone.add_attributes({
          'name' => 'VZ',
          'id' => index_creation(generate_index("vz", unite_info[:name], numero_upeb))
        })
        epb_unit.add_element(ventilation_zone)

        energetic_sector = REXML::Element.new('urn:EnergeticSector')
        energetic_sector.add_attributes({
          'name' => 'ES',
          'id' => index_creation(generate_index("es", unite_info[:name], numero_upeb))
        })
        ventilation_zone.add_element(energetic_sector)

        volume = REXML::Element.new('urn:volume')
        volume.text = unite_info[:volume].to_s
        energetic_sector.add_element(volume)

        energetic_sector_content = REXML::Element.new('urn:EnergeticSectorContent')
        energetic_sector.add_element(energetic_sector_content)

        process_constructions(energetic_sector_content, unite_info[:name], fused_faces_infos)
      end

      def process_constructions(parent, unite_name, fused_faces_infos)
        fused_faces_infos.each do |_, face_info|
          next unless face_info["Groupe"] == unite_name
          next if face_info["Type de paroi"] == "Inconnu" || face_info["ID de la paroi"] == "Inconnu"
          next if face_info["Type de paroi"] == "Plafond" && (face_info["ID Espace adjacent"] == "OPEB" || face_info["ID Espace adjacent"] == "MPEB")

          if face_info["ID Espace adjacent"] == "Inconnu" || ESPACE_ADJACENT_DICT[face_info["ID Espace adjacent"]].nil?
            show_error_dialog("Erreur: Espace adjacent 'Inconnu' pour la face #{face_info["Nom PEB"]}")
            next
          end

          construction = REXML::Element.new('urn:Construction')
          construction.add_attributes({
            'name' => face_info["Nom PEB"],
            'id' => face_info["ID PEB"]
          })
          parent.add_element(construction)
          
          if face_info["ID meme face"].nil? || face_info["ID meme face"].empty?
            environment_type = REXML::Element.new('urn:environmentType')
            environment_type.text = ESPACE_ADJACENT_DICT[face_info["ID Espace adjacent"]] || "Inconnu"
            construction.add_element(environment_type)
        
            construction_type = REXML::Element.new('urn:constructionType')
            construction_type.text = TYPE_PAROI_DICT[face_info["ID de la paroi"].gsub(/\d+$/, '')]
            construction.add_element(construction_type)
        
            surface = REXML::Element.new('urn:surface')
            surface.text = sprintf('%.2f', face_info["Surface (m²)"])
            construction.add_element(surface)
        
            if face_info["Inclinaison"] != "None" && face_info["Type de paroi"] == "Fenetre de toit"
              slope = REXML::Element.new('urn:slope')
              slope.text = face_info["Inclinaison"].to_s
              construction.add_element(slope)
            end

            if face_info["Orientation"] != "None"
              orientation = REXML::Element.new('urn:orientation')
              orientation.text = face_info["Orientation"].to_s
              construction.add_element(orientation)
            end
        
            if face_info["Valeur U"]
              u_value = REXML::Element.new('urn:u-value')
              u_value.text = sprintf('%.2f', face_info["Valeur U"])
              construction.add_element(u_value)
            end
          else
            construction_ref = REXML::Element.new('urn:construction-ref')
            construction_ref.add_attribute('ids', face_info["ID meme face"])
            construction.add_element(construction_ref)     
          end
        end
      end
    end
  end
end