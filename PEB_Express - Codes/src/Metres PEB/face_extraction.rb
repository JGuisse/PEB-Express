module Guisse
  module PEBExpress
    TOLERANCE = 0.01
    INCH_TO_METER = 0.0254

    class << self
      $existing_indices = []

      def get_face_info(face, parent_name, transformation)
        {
          group: parent_name,
          material: face.material ? face.material.display_name : "Aucun",
          area_m2: face.area * INCH_TO_METER**2,
          face_center: extract_face_center(face, transformation),
          groupe_adjacent: [],
          face_length: "None",
          face_orientation: "None",
          slope: calculate_face_slope(face).round(0).to_s.gsub('.', ',')
        }.tap do |info|
          classify_face(info, face)
        end
      rescue StandardError => e
        puts "Erreur lors de l'obtention des informations de la face : #{e.message}"
        {}
      end

      def extract_face_center(face, transformation)
        center_point = face.bounds.center
        absolute_center = center_point.transform(transformation)
        absolute_center.to_a.map { |coord| coord * INCH_TO_METER }
      rescue StandardError => e
        puts "Erreur lors de l'extraction du centre de la face : #{e.message}"
        [0, 0, 0]
      end

      def classify_face(face_info, face)
        name_parts = face_info[:material].split('_')
        face_info[:id_material] = name_parts.first
        face_info[:type_face] = determine_face_type(name_parts.first)
        face_info[:face_statut] = determine_face_status(name_parts[2].to_s)
        face_info[:id_adjacent_space] = determine_id_adjacent_space(face_info[:type_face], name_parts[1])
        face_info[:adjacent_space] = determine_adjacent_space(face_info[:type_face], name_parts[1])

        if ["Inconnu"].include?(face_info[:type_face])
          face_info[:face_statut] = "Inconnu"  
          face_info[:id_adjacent_space] = "Inconnu"
          face_info[:adjacent_space] = "Inconnu"
        end

        if ["Fenetre", "Porte", "Mur rideau", "Lanterneau"].include?(face_info[:type_face])
          if name_parts[-1]
            face_info[:face_orientation] = name_parts[-1].slice(0, name_parts[-1].length - 1).to_f
          end
          if name_parts[-3]
            face_info[:face_length] = name_parts[-3].scan(/\((\d+\.\d+)/).flatten.first.to_f
          end
          if face_info[:slope] != "90" 
            face_info[:type_face] = "Fenetre de toit"
          end
        else
          face_info[:slope] = "None"
        end
      end

      def determine_face_type(first_part)
        case first_part
        when /^PCH/ then "Plancher"
        when /^MR/  then "Mur rideau"
        when /^BV/  then "Brique de ver"
        when /^MC/  then "Mur Capteur"
        when /^M/   then "Mur"
        when /^T/   then "Toiture"
        when /^F/   then "Fenetre"
        when /^L/   then "Lanterneau"
        when /^P/   then "Porte"  
        else "Inconnu"
        end
      end

      def determine_face_status(third_part)
        case third_part
        when "N" then "Neuf"
        when "R" then "Renove"
        when "E" then "Existant"
        else "Neuf"
        end
      end

      def determine_id_adjacent_space(face_type, second_part)
        ["Fenetre", "Porte", "Mur rideau", "Lanterneau", "Fenetre de toit"].include?(face_type) ? "EXT" : second_part
      end

      def determine_adjacent_space(face_type, second_part)
        case second_part
        when "EXT" then "Extérieur"
        when "EAC" then "Espace chauffé"
        when "EANC"  then "Espace non chauffé"
        when "OPEB"  then "Autre Unité PEB"
        when "MPEB"  then "Même unité PEB"
        when "IND"   then "Industriel"
        when "SOL"   then "Sol"
        when "CAVE"   then "Cave"
        when "VV"  then "Vide sanitaire"
        else
          if ["Fenetre", "Porte", "Mur rideau", "Lanterneau", "Fenetre de toit"].include?(face_type)
            "Extérieur"
          else
            "Inconnu"
          end
        end
      end

      def get_group_volumes(group, unit_name)
        return { name: unit_name, volume: 0 } unless group.is_a?(Sketchup::Group) || group.is_a?(Sketchup::ComponentInstance)
        
        volume_in_cubic_meters = if group.manifold?
          group.volume * (INCH_TO_METER**3)
        else
          0
        end

        { name: unit_name, volume: volume_in_cubic_meters }
      rescue StandardError => e
        puts "Erreur lors du calcul du volume du groupe : #{e.message}"
        { name: unit_name, volume: 0 }
      end

      def process_entities(entities, parent_name = "Root", transformation = Geom::Transformation.new)
        face_infos = {}
        entities.each do |entity|
          case entity
          when Sketchup::Face
            face_infos[entity.entityID] = get_face_info(entity, parent_name, transformation)
          when Sketchup::Group
            sub_entities = entity.entities
            sub_transformation = transformation * entity.transformation
            sub_parent_name = entity.name.empty? ? "Sans Nom" : entity.name
            face_infos.merge!(process_entities(sub_entities, sub_parent_name, sub_transformation))
          when Sketchup::ComponentInstance
            sub_entities = entity.definition.entities
            sub_transformation = transformation * entity.transformation
            sub_parent_name = entity.definition.name.empty? ? "Sans Nom" : entity.definition.name
            face_infos.merge!(process_entities(sub_entities, sub_parent_name, sub_transformation))
          end
        end
        face_infos
      end

      def find_adjacent_faces(face_infos)
        face_infos.each do |entityID, face_info|
          center1 = face_info[:face_center]
          face_infos.each do |other_entityID, other_face_info|
            next if entityID == other_entityID || face_info[:group] == other_face_info[:group]
            center2 = other_face_info[:face_center]
            if centers_are_close(center1, center2)
              face_info[:groupe_adjacent] << other_face_info[:group]
            end
          end
        end
      end

      def centers_are_close(center1, center2)
        return false if center1.nil? || center2.nil?
        center1.zip(center2).all? { |c1, c2| (c1 - c2).abs < TOLERANCE }
      end

      def fuse_faces(face_infos)
        fused_faces_infos = {}
        counters = { "Fenetre" => 0, "Porte" => 0, "Mur rideau" => 0, "Lanterneau" => 0, "Fenetre de toit" => 0}
        
        face_infos.each do |_, info|
          if ["Fenetre", "Porte", "Mur rideau", "Lanterneau", "Fenetre de toit"].include?(info[:type_face])
            counters[info[:type_face]] += 1
            key = "#{info[:type_face]}_#{counters[info[:type_face]]}"
          else
            key = [info[:group], info[:material], (info[:groupe_adjacent] || []).sort.join(',')]
          end
          
          fused_info = {
            "Type" => "Face",
            "Groupe" => info[:group],
            "Matériau" => info[:material],
            "Surface (m²)" => info[:area_m2],
            "Groupes adjacents" => (info[:groupe_adjacent] || []).sort.join(', '),
            "Type de paroi" => info[:type_face],
            "ID de la paroi" => info[:id_material],
            "ID Espace adjacent" => info[:id_adjacent_space],
            "Espace adjacent" => info[:adjacent_space],
            "Etat de la paroi" => info[:face_statut],
            "Orientation" => info[:face_orientation],
            "Inclinaison" => info[:slope],
            "Longueur" => info[:face_length]
          }
          
          if fused_faces_infos.has_key?(key) && !["Fenetre", "Porte", "Mur rideau", "Lanterneau", "Fenetre de toit"].include?(info[:type_face])
            fused_faces_infos[key]["Surface (m²)"] += info[:area_m2]
          else
            fused_faces_infos[key] = fused_info
          end
        end
        
        sorted_fused_faces = fused_faces_infos.sort_by do |key, info|
          [
            info["Groupe"],
            info["Type de paroi"] == "Inconnu" ? "" : info["Type de paroi"], #Fait apparaitre "Inconnu" en premier
            info["Matériau"],
            info["Groupes adjacents"]
          ]
        end
        
        sorted_fused_faces.to_h.each do |_, face_info|
          if face_info["Surface (m²)"].nil?
            face_info["Surface (m²)"] = 0
          end
          if face_info["Groupes adjacents"].nil? || face_info["Groupes adjacents"].empty?
          # Avant : face_info["Nom PEB"] = "#{face_info["Groupe"]}_#{face_info["Matériau"]}_#{face_info["Surface (m²)"].round(2)} m²"
            if ["Fenetre", "Porte", "Mur rideau", "Lanterneau", "Fenetre de toit"].include?(face_info["Type de paroi"])
              face_info["Nom PEB"] = "#{face_info["Matériau"]}"
            else
              face_info["Nom PEB"] = "#{face_info["Matériau"]}_#{face_info["Surface (m²)"].round(2)} m²"
            end
          else
            face_info["Nom PEB"] = "#{face_info["Matériau"]}_#{face_info["Groupe"]} vers #{face_info["Groupes adjacents"]}_#{face_info["Surface (m²)"].round(2)} m²"
          end
          face_info["ID PEB"] = index_creation_paroi("#{face_info["Groupe"]}_#{face_info["Nom PEB"]}")
        end

        sorted_fused_faces.each do |key1, face1|
          next if face1["Groupes adjacents"].nil? || face1["Groupes adjacents"].empty?
          next if face1["ID meme face"]

          sorted_fused_faces.each do |key2, face2|
            next if key1 == key2
            next if face2["ID meme face"]

            if face1["Matériau"] == face2["Matériau"] &&
              face1["Surface (m²)"].round(2) == face2["Surface (m²)"].round(2) &&
              face1["Groupes adjacents"].include?(face2["Groupe"]) &&
              face2["Groupes adjacents"].include?(face1["Groupe"])

              face2["ID meme face"] = face1["ID PEB"]
              break
            end
          end
        end

        sorted_fused_faces.to_h
      end

      def sort_face_infos(face_infos)
        sorted_face_infos = face_infos.sort_by do |_, info|
          [
            info[:group],
            info[:material],
            (info[:groupe_adjacent] || []).sort.join(',')
          ]
        end
      
        sorted_face_infos.to_h
      end
      
      # Nouvelle méthode pour calculer l'angle de la face par rapport à l'horizontale
      def calculate_face_slope(face)
        if face.is_a?(Sketchup::Face)
          # Obtenir le vecteur normal de la face
          normal = face.normal

          # Calculer l'angle entre le vecteur normal et l'axe vertical (0, 0, 1)
          angle_rad = normal.angle_between([0, 0, 1])

          # Convertir l'angle en degrés
          angle_deg = angle_rad * 180 / Math::PI

          # Ajuster l'angle pour qu'il soit toujours entre 0° et 90°
          # angle_deg = 90 - angle_deg if angle_deg > 90

          # Arrondir l'angle à deux décimales
          angle_deg.round(2)
        else
          nil
        end
      rescue StandardError => e
        puts "Erreur lors du calcul de l'angle de la face : #{e.message}"
        nil
      end

      def index_creation_paroi(chaine)
        chaine = chaine.encode('UTF-8', invalid: :replace, undef: :replace, replace: '')
        nouvelle_chaine = chaine.unicode_normalize(:nfkd).encode('ASCII', invalid: :replace, undef: :replace, replace: '')
        nouvelle_chaine = nouvelle_chaine.scan(/[a-zA-Z0-9]/).join
        nouvelle_chaine = "X" + nouvelle_chaine if nouvelle_chaine[0] =~ /\d/
        if nouvelle_chaine.empty?
          nouvelle_chaine = "X#{rand(100000..999999)}"
        end
        original_chaine = nouvelle_chaine
        counter = 1
        while $existing_indices.include?(nouvelle_chaine)
          nouvelle_chaine = "#{original_chaine}#{counter}"
          counter += 1
        end
        $existing_indices << nouvelle_chaine
        nouvelle_chaine
      end
    end
  end
end
