require 'sketchup.rb'

module Guisse
  module PEBExpress
    INCH_TO_METER = 0.0254
    MATERIALS_ELEVATION = {
      adjacent: {
        name: "MXY_OPEB_Mur entre unité généré",
        color: Sketchup::Color.new(147, 112, 219)
      },
      exterior: {
        name: "MXX_EXT_Mur extérieur généré",
        color: Sketchup::Color.new(255, 200, 200)
      },
      floor: {
        name: "PCHXX_SOL_Plancher contre sol généré",
        color: Sketchup::Color.new(255, 255, 200)
      },
      roof: {
        name: "TXX_EXT_Toiture extérieur générée",
        color: Sketchup::Color.new(200, 255, 200)
      }
    }

    extend self

    def create_elevation_toolbar
      toolbar = UI::Toolbar.new("Elevation des surfaces")
      cmd = UI::Command.new("Elevation des surfaces") {
        create_elevation_dialog
      }
      cmd.small_icon = File.join(__dir__, '../images/logo_elevation_16x16.png')
      cmd.large_icon = File.join(__dir__, '../images/logo_elevation_24x24.png')
      cmd.tooltip = "Elevation des surfaces"
      cmd.status_bar_text = "Elever les surfaces sélectionnées en groupes/composants et coloration des parois"
      toolbar.add_item(cmd)
      toolbar.show
    end

    def create_elevation_dialog
      @dialog_extrude = UI::WebDialog.new("Elevation des surfaces", false, "ExtrustionTool", 320, 420)
      html_content = '
        <html>
        <head>
          <meta charset="UTF-8">
          <style>
            body {
              font-family: system-ui, -apple-system, sans-serif;
              padding: 20px;
              background: #f5f5f5;
              color: #333;
            }
            .container {
              background: white;
              padding: 20px;
              border-radius: 8px;
              box-shadow: 0 2px 4px rgba(0,0,0,0.1);
            }
            .input-group {
              margin-bottom: 20px;
            }
            .input-group h3 {
              color: #2c3e50;
              font-size: 16px;
              margin-bottom: 12px;
            }
            input[type="number"] {
              width: 100%;
              padding: 8px;
              border: 1px solid #ddd;
              border-radius: 4px;
              font-size: 14px;
            }
            .radio-group {
              display: flex;
              gap: 15px;
              margin: 10px 0;
            }
            .checkbox-group {
              margin-bottom: 12px;
            }
            .checkbox-group label {
              display: flex;
              align-items: center;
              gap: 8px;
              cursor: pointer;
            }
            button {
              width: 100%;
              padding: 10px;
              background: #2196F3;
              color: white;
              border: none;
              border-radius: 4px;
              font-size: 14px;
              cursor: pointer;
              transition: background 0.3s;
            }
            button:hover {
              background: #1976D2;
            }
            input[type="checkbox"] {
              width: 16px;
              height: 16px;
            }
          </style>
        </head>
        <body>
          <div class="container">
            <div class="input-group">
              <h3>Hauteur (mètres)</h3>
              <input type="number" id="height" step="0.1" min="0">
            </div>
            
            <div class="input-group">
              <h3>Type de conteneur</h3>
              <div class="radio-group">
                <label>
                  <input type="radio" name="container" value="group" checked>
                  Groupe
                </label>
                <label>
                  <input type="radio" name="container" value="component">
                  Composant
                </label>
              </div>
            </div>

            <div class="input-group">
              <h3>Surfaces à colorer</h3>
              <div class="checkbox-group">
                <label>
                  <input type="checkbox" id="color_adjacent" checked>
                  Murs adjacents
                </label>
              </div>
              <div class="checkbox-group">
                <label>
                  <input type="checkbox" id="color_exterior" checked>
                  Murs extérieurs
                </label>
              </div>
              <div class="checkbox-group">
                <label>
                  <input type="checkbox" id="color_floor" checked>
                  Planchers
                </label>
              </div>
              <div class="checkbox-group">
                <label>
                  <input type="checkbox" id="color_roof" checked>
                  Toitures
                </label>
              </div>
            </div>

            <button onclick="submitValues()">Valider</button>
          </div>

          <script>
            function submitValues() {
              var height = document.getElementById("height").value;
              var container = document.querySelector("input[name=container]:checked").value;
              var colorOptions = {
                adjacent: document.getElementById("color_adjacent").checked,
                exterior: document.getElementById("color_exterior").checked,
                floor: document.getElementById("color_floor").checked,
                roof: document.getElementById("color_roof").checked
              };
              window.location = "skp:submit@" + height + "@" + container + "@" + JSON.stringify(colorOptions);
            }
          </script>
        </body>
        </html>'

      @dialog_extrude.set_html(html_content)
      @dialog_extrude.add_action_callback("submit") { |dlg, params|
        height, container_type, color_options = params.split("@")
        color_options = eval(color_options)
        process_elevation(height.to_f, container_type, color_options)
        dlg.close
      }
      @dialog_extrude.show
    end

    def process_elevation(height, container_type, color_options)
      model = Sketchup.active_model
      selection = model.selection.to_a
      faces = selection.grep(Sketchup::Face)
      edges = selection.grep(Sketchup::Edge)
      
      # Filtrer les faces valides
      valid_faces = faces.select do |face|
        area = face.area
        if area < 1  # 1m² comme seuil minimum
          puts "Face ignorée : aire trop petite (#{area}m²)"
          false
        else
          true
        end
      end
      
      return if valid_faces.empty?
      
      model.start_operation('elevation des surfaces', true)
      @created_groups = extrude_selected_faces(valid_faces, height, container_type)

      # Vérifier et supprimer les groupes trop petits
      @created_groups.reject! do |group|
        volume = group.volume * (INCH_TO_METER**3)
        if volume < 1.0
          puts "Groupe supprimé : volume = #{volume.round(2)} m³ (< 1 m³)"
          # group.erase!
          true
        else
          false
        end
      end

      color_all_surfaces(color_options)
      model.active_entities.erase_entities(edges) unless edges.empty?
      model.selection.clear
      model.commit_operation
    end

    def calculate_geometry_center_elevated(face)
      bounds = face.bounds
      [bounds.min.x, bounds.min.y, bounds.min.z]
    end

    def create_container(model, type, index, face)
      origin = calculate_geometry_center_elevated(face)
      transform = Geom::Transformation.new(origin)
      
      if type == 'group'
        group = model.active_entities.add_group
        group.name = sprintf("Unité %02d", index + 1)
        group.transform!(transform)
        [group, group.entities]
      else
        definition = model.definitions.add(sprintf("Unité %02d", index + 1))
        instance = model.active_entities.add_instance(definition, transform)
        [instance, definition.entities]
      end
    end

    def create_materials_elevated(model)
      materials = {}
      MATERIALS_ELEVATION.each do |key, data|
        # Chercher d'abord si le matériau existe déjà
        existing_material = model.materials.find { |m| m.name == data[:name] }
        
        if existing_material
          # Utiliser le matériau existant
          materials[key] = existing_material
          puts "Utilisation du matériau existant : #{data[:name]}"
        else
          # Créer un nouveau matériau si nécessaire
          material = model.materials.add(data[:name])
          material.color = data[:color]
          materials[key] = material
          puts "Création d'un nouveau matériau : #{data[:name]}"
        end
      end
      materials
    end

    def extrude_selected_faces(faces, height, container_type)
      model = Sketchup.active_model
      created_groups = []
      
      faces.each_with_index do |face, index|
        # Vérification supplémentaire de la validité de la face
        next unless face.valid? && face.vertices.length >= 3
        
        container, entities = create_container(model, container_type, index, face)
        created_groups << container
        
        origin = calculate_geometry_center_elevated(face)
        points = face.outer_loop.vertices.map { |v| 
          pt = v.position
          Geom::Point3d.new(pt.x - origin[0], pt.y - origin[1], pt.z - origin[2])
        }
        
        # Vérification supplémentaire que les points forment une face valide
        begin
          new_face = entities.add_face(points)
          if new_face && new_face.valid? && new_face.area > 1
            new_face.reverse! if new_face.normal.z < 0
            new_face.pushpull(height.m)
          else
            puts "Face invalide créée pour le groupe #{index + 1} - Suppression du groupe"
            container.erase! if container.valid?
            created_groups.pop
          end
        rescue StandardError => e
          puts "Erreur lors de la création de la face pour le groupe #{index + 1}: #{e.message}"
          container.erase! if container.valid?
          created_groups.pop
        end
      end
      
      model.active_entities.erase_entities(faces)
      created_groups
    end

    def project_points_to_plane(points)
      return points if points.length < 3
      
      # Calculer le plan moyen
      normal = calculate_average_normal(points)
      point_on_plane = geometric_center(points)
      
      # Projeter chaque point sur le plan
      points.map { |p|
        project_point_to_plane(p, point_on_plane, normal)
      }
    end
    
    def calculate_average_normal(points)
      return Geom::Vector3d.new(0, 0, 1) if points.length < 3
      
      # Calculer la normale en utilisant les trois premiers points
      p1 = Geom::Point3d.new(points[0])
      p2 = Geom::Point3d.new(points[1])
      p3 = Geom::Point3d.new(points[2])
      
      vector1 = p2.vector_to(p1)
      vector2 = p2.vector_to(p3)
      
      normal = vector1.cross(vector2)
      normal.normalize!
      normal
    end
    
    def geometric_center(points)
      return [0, 0, 0] if points.empty?
      
      sum = points.reduce([0, 0, 0]) { |acc, p| 
        [acc[0] + p[0], acc[1] + p[1], acc[2] + p[2]]
      }
      
      count = points.length.to_f
      [sum[0]/count, sum[1]/count, sum[2]/count]
    end
    
    def project_point_to_plane(point, point_on_plane, normal)
      # Vecteur du point sur le plan au point à projeter
      v = [
        point[0] - point_on_plane[0],
        point[1] - point_on_plane[1],
        point[2] - point_on_plane[2]
      ]
      
      # Calculer la distance du point au plan
      dist = (v[0] * normal.x + v[1] * normal.y + v[2] * normal.z)
      
      # Projeter le point sur le plan
      [
        point[0] - dist * normal.x,
        point[1] - dist * normal.y,
        point[2] - dist * normal.z
      ]
    end
    
    def points_are_valid?(points)
      return false if points.length < 3
      
      # Vérifier que tous les points sont des Point3d
      return false unless points.all? { |p| p.is_a?(Geom::Point3d) }
      
      # Vérifier que les points ne sont pas tous alignés
      if points.length == 3
        vector1 = points[0].vector_to(points[1])
        vector2 = points[0].vector_to(points[2])
        return false if vector1.parallel?(vector2)
      end
      
      true
    end

    def color_all_surfaces(color_options)
      return if @created_groups.empty?
      
      model = Sketchup.active_model
      model.start_operation('Coloration des surfaces', true)
      
      materials = create_materials_elevated(model)
      
      @created_groups.each do |group|
        color_surfaces_elevated(group, materials, color_options)
      end
      
      @created_groups.each_with_index do |group1, i|
        @created_groups[(i + 1)..-1].each do |group2|
          check_and_color_adjacent_faces(group1, group2, materials[:adjacent], color_options)
        end
      end
      
      model.commit_operation
    end

    def color_surfaces_elevated(container, materials, color_options)
      faces = get_all_faces_elevated(container)
      colored_faces = Set.new
      
      faces.each do |face|
        next if colored_faces.include?(face)
        
        normal = face.normal.transform!(get_transformation(face))
        
        if normal.z.abs > 0.9
          if face.vertices.map { |v| v.position.z }.max > container.bounds.max.z - 0.1
            face.material = materials[:roof] if color_options[:roof]
          else
            face.material = materials[:floor] if color_options[:floor]
          end
        else
          face.material = materials[:exterior] if color_options[:exterior]
        end
        
        colored_faces.add(face)
      end
    end

    def check_and_color_adjacent_faces(group1, group2, material, color_options)
      return unless color_options[:adjacent]
      
      faces1 = get_all_faces_elevated(group1)
      faces2 = get_all_faces_elevated(group2)
      
      faces1.each do |face1|
        next unless face1.normal.transform!(get_transformation(face1)).z.abs < 0.9
        
        faces2.each do |face2|
          next unless face2.normal.transform!(get_transformation(face2)).z.abs < 0.9
          
          if faces_adjacent_elevated?(face1, face2)
            face1.material = material
            face2.material = material
          end
        end
      end
    end

    def get_all_faces_elevated(group)
      entities = if group.is_a?(Sketchup::Group)
        group.entities
      else
        group.definition.entities
      end
      entities.grep(Sketchup::Face)
    end

    def get_transformation(face)
      if face.parent.is_a?(Sketchup::ComponentDefinition)
        @created_groups.find { |g| g.definition == face.parent }.transformation
      else
        face.parent.parent.transformation
      end
    end

    def faces_adjacent_elevated?(face1, face2)
      trans1 = get_transformation(face1)
      trans2 = get_transformation(face2)

      center1 = calculate_face_center_elevated(face1).transform(trans1)
      center2 = calculate_face_center_elevated(face2).transform(trans2)
      
      normal1 = face1.normal.transform(trans1)
      normal2 = face2.normal.transform(trans2)
      
      angle = normal1.angle_between(normal2)
      return false if angle < 170.degrees || angle > 190.degrees
      
      center1_xy = Geom::Point3d.new(center1.x, center1.y, 0)
      center2_xy = Geom::Point3d.new(center2.x, center2.y, 0)
      
      distance = center1_xy.distance(center2_xy)
      tolerance = calculate_tolerance(face1, face2)
      
      distance <= tolerance
    end

    def calculate_face_center_elevated(face)
      vertices = face.vertices
      sum = Geom::Point3d.new(0, 0, 0)
      vertices.each { |v| sum.offset!(v.position.to_a.map { |c| c / vertices.length }) }
      sum
    end

    def calculate_tolerance(face1, face2)
      diagonal1 = face1.bounds.diagonal
      diagonal2 = face2.bounds.diagonal
      [diagonal1, diagonal2].min * 0.05
    end
    

    unless file_loaded?(__FILE__)
      create_elevation_toolbar
    end
    file_loaded(__FILE__)
  end
end