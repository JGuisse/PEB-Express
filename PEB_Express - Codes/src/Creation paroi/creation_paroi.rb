require 'sketchup.rb'

module Guisse
  module PEBExpress
    @dialog_crea_paroi = nil

    def self.creer_dialogue
      
      @dialog_crea_paroi = UI::HtmlDialog.new({
        :dialog_title => "Nommer et Colorer Paroi",
        :scrollable => true,
        :resizable => true,
        :width => 500,
        :height => 900,
        :style => UI::HtmlDialog::STYLE_DIALOG
      })

      html_path = File.join(File.dirname(__FILE__), 'html_crea_paroi.html')
      @dialog_crea_paroi.set_file(html_path)

      @dialog_crea_paroi.add_action_callback("appliquer_nom_et_couleur") { |action_context, type, indice, nom_paroi, angle, espace_adjacent, etat_paroi, couleur|
        if validate_input(indice, angle)
          angle = angle.to_f
          puts "Appel fonction"
          # Convertir la chaîne JSON en hash Ruby
          # couleur = JSON.parse(couleur, symbolize_names: true) if couleur
          self.appliquer_nom_et_couleur(type, indice, nom_paroi, angle, espace_adjacent, etat_paroi, couleur)
        else
          UI.messagebox("Entrées invalides. Veuillez vérifier l'indice (01-99) et l'angle (-360° à 360°).")
        end
      }

      @dialog_crea_paroi.add_action_callback("creer_nouvelle_paroi") do |action_context, type, indice, nom_paroi, angle, espace_adjacent, etat_paroi, largeur, hauteur|
        if validate_input(indice, angle)
          angle = angle.to_f if angle.is_a?(String)
          self.creer_nouvelle_paroi(type, indice, nom_paroi, angle, espace_adjacent, etat_paroi, largeur.to_f, hauteur.to_f)
        else
          UI.messagebox("Entrées invalides. Veuillez vérifier l'indice (01-99) et l'angle (-360° à 360°).")
        end
      end

      @dialog_crea_paroi.show
    end

    def self.validate_input(indice, angle)
      indice_valid = indice =~ /^(0[1-9]|[1-9]\d)$/
      angle_valid = angle.to_f.between?(-360, 360)
      indice_valid && angle_valid
    end

    def self.appliquer_nom_et_couleur(type, indice, nom_paroi, angle, espace_adjacent = nil, etat_paroi = nil, couleur = nil)
      model = Sketchup.active_model
      entities = model.active_entities
      selection = model.selection
      layers = model.layers
      materials = model.materials

      case type
      when "Fenetre"
        layer_name = 'Noms des Fenêtres'
        indice_prefix = "F"
        color = "cyan"
      when "Porte"
        layer_name = 'Noms des Portes'
        indice_prefix = "P"
        color = Sketchup::Color.new(191, 148, 228)
      when "MurRideau"
        layer_name = 'Noms des Murs Rideaux'
        indice_prefix = "MR"
        color = Sketchup::Color.new(101, 101, 255)
      when "Mur"
        layer_name = 'Noms des Murs'
        indice_prefix = "M"
        color = couleur ? Sketchup::Color.new(couleur['r'].to_i, couleur['g'].to_i, couleur['b'].to_i) : Sketchup::Color.new(255, 127, 0)
      when "Plancher"
        layer_name = 'Noms des Sols - Planchers'
        indice_prefix = "PCH"
        color = couleur ? Sketchup::Color.new(couleur['r'].to_i, couleur['g'].to_i, couleur['b'].to_i) : Sketchup::Color.new(255, 0, 0)
      when "Toiture"
        layer_name = 'Noms des Toitures'
        indice_prefix = "T"
        color = couleur ? Sketchup::Color.new(couleur['r'].to_i, couleur['g'].to_i, couleur['b'].to_i) : Sketchup::Color.new(127, 255, 0)
      when "BriqueDeVerre"
        layer_name = 'Noms des Briques de verre'
        indice_prefix = "BV"
        color = couleur ? Sketchup::Color.new(couleur['r'].to_i, couleur['g'].to_i, couleur['b'].to_i) : Sketchup::Color.new(173, 216, 230)
      when "MurCapteur"
        layer_name = 'Noms des Murs Capteurs'
        indice_prefix = "MC"
        color = couleur ? Sketchup::Color.new(couleur['r'].to_i, couleur['g'].to_i, couleur['b'].to_i) : Sketchup::Color.new(255, 215, 0)
      when "Lanterneau"
        layer_name = 'Noms des Lanterneaux'
        indice_prefix = "L"
        color = couleur ? Sketchup::Color.new(couleur['r'].to_i, couleur['g'].to_i, couleur['b'].to_i) : Sketchup::Color.new(255, 0, 127)
      end
    

      if ["Fenetre", "Porte", "MurRideau"].include?(type)
        layer_text = layers[layer_name] || layers.add(layer_name)
      end
    
      if selection.empty?
        UI.messagebox("Aucune face sélectionnée.")
        return
      end
    
      faces = selection.grep(Sketchup::Face)
      if faces.empty?
        UI.messagebox("La sélection ne contient aucune face.")
        return
      end
    
      model.start_operation('Création paroi', true)
    
      single_face = faces.length == 1
    
      faces.each_with_index do |entity, index|
        if entity.nil?
          UI.messagebox("La face #{index} est nil.")
          next
        end
    
        surface = entity.area.to_f * 0.0254 * 0.0254
        
        normal = entity.normal
        if normal.nil?
          UI.messagebox("La normale de la face #{index} est nil.")
          next
        end
    
        vertical = (normal.parallel?(Z_AXIS) || normal.parallel?(Z_AXIS.reverse))
      
        horizontales_edges = []
        verticales_edges = []
        entity.edges.each do |edge|
          if edge.nil? || edge.line.nil?
            UI.messagebox("Une arête de la face #{index} est nil ou n'a pas de ligne.")
            next
          end
          if vertical
            horizontales_edges << edge if edge.line[1].parallel?(Z_AXIS) || edge.line[1].parallel?(Z_AXIS.reverse)
            verticales_edges << edge unless edge.line[1].parallel?(Z_AXIS) || edge.line[1].parallel?(Z_AXIS.reverse)
          else
            up_direction = normal * Z_AXIS
            if up_direction.nil?
              UI.messagebox("La direction verticale de la face #{index} est nil.")
              next
            end
            if edge.line[1].parallel?(up_direction) || edge.line[1].parallel?(up_direction.reverse)
              horizontales_edges << edge
            else
              verticales_edges << edge
            end
          end
        end
      
        longueur = horizontales_edges.map(&:length).max.to_f * 0.0254
        hauteur = verticales_edges.map(&:length).max.to_f * 0.0254
    
        face_normal = entity.normal.normalize
        
        is_light_partition = ["Fenetre", "Porte", "MurRideau"].include?(type)
              
        nom_complet = "#{indice_prefix}#{indice}"
        nom_complet += "_#{espace_adjacent}" if espace_adjacent
        nom_complet += "_#{etat_paroi}" if etat_paroi
        nom_complet += "_#{nom_paroi}"

        if is_light_partition
          nom_complet += " (#{index+1})" unless single_face
          north_vector = Geom::Vector3d.new(Math.sin(angle * Math::PI / 180), Math.cos(angle * Math::PI / 180), 0)
          angle_degrees = calculate_angle(entity, north_vector)
          nom_complet += "_(#{'%.2f' % longueur}mx#{'%.2f' % hauteur}m)_#{'%.2f' % surface}m²_#{'%.1f' % angle_degrees}°"
        end
        texte = "#{nom_paroi}"
        texte += " (#{index+1})" unless single_face
        
        mat = materials[nom_complet]
        if mat.nil?
          mat = materials.add(nom_complet)
          mat.color = color
        end
    
        entity.material = mat
        
        if is_light_partition
          point = entity.bounds.center
          decalage = entity.normal
          decalage.length = 100.cm
          point_decal = point.offset(decalage)
          
          # Recherche d'un texte existant près de la face
          existing_text = entities.grep(Sketchup::Text).find { |t| t.point.distance(point_decal) < 1.cm }
          
          if existing_text
            # Si un texte existe, mettez à jour son contenu et sa position
            existing_text.text = texte
            existing_text.point = point_decal
            existing_text.layer = layer_text
          else
            # Si aucun texte n'existe, créez-en un nouveau
            text = entities.add_text(texte, point_decal)
            text.layer = layer_text
          end
        end
      end
    
      model.commit_operation
      
      @dialog_crea_paroi.execute_script("updateFacesModifiees(#{faces.length})")
    end
    
    def self.calculate_angle(entity, north_vector)
      face_normal = entity.normal.normalize
      face_normal_proj = Geom::Vector3d.new(face_normal.x, face_normal.y, 0).normalize
      angle_radians = north_vector.angle_between(face_normal_proj)
      angle_degrees = angle_radians * 180 / Math::PI
      cross_product = north_vector * face_normal_proj
      angle_degrees = 360 - angle_degrees if cross_product.z < 0
      angle_degrees = -1 * (angle_degrees - 180)
      angle_degrees = -angle_degrees if angle_degrees == -0
      (angle_degrees / 2.5).round * 2.5
    end

    def self.creer_nouvelle_paroi(type, indice, nom_paroi, angle, espace_adjacent, etat_paroi, largeur, hauteur)
      model = Sketchup.active_model
    
      largeur = largeur.to_f
      hauteur = hauteur.to_f
    
      tool = CreationParoiTool.new(type, indice, nom_paroi, angle, espace_adjacent, etat_paroi, largeur, hauteur, @dialog_crea_paroi)
      model.select_tool(tool)
    end

    def self.incrementer_nom_paroi(nom_paroi)
      if nom_paroi =~ /\(\d+\)$/
        base_nom, index = nom_paroi.match(/^(.+)\((\d+)\)$/).captures
        nouveau_index = index.to_i + 1
        "#{base_nom.strip} (#{nouveau_index})"
      else
        "#{nom_paroi} (1)"
      end
    end

    class CreationParoiTool
      def initialize(type, indice, nom_paroi, angle, espace_adjacent, etat_paroi, largeur, hauteur, dialog)
        @type = type
        @indice = indice
        @nom_paroi = nom_paroi
        @angle = angle
        @espace_adjacent = espace_adjacent
        @etat_paroi = etat_paroi
        @largeur = largeur.to_f.m
        @hauteur = hauteur.to_f.m
        @mouse_ip = Sketchup::InputPoint.new
        @preview = nil
        @preview_color = Sketchup::Color.new(0, 255, 255, 128)
        @dialog_crea_paroi = dialog
      end
    
      def activate
        update_ui
      end
    
      def deactivate(view)
        view.invalidate
      end
    
      def resume(view)
        update_ui
        view.invalidate
      end
    
      def onMouseMove(flags, x, y, view)
        @mouse_ip.pick(view, x, y)
        update_preview(view)
        view.invalidate
      end
    
      def onLButtonDown(flags, x, y, view)
        create_paroi(view) if @mouse_ip.valid?
      end
    
      def draw(view)
        if @preview
          view.drawing_color = @preview_color
          view.draw(GL_QUADS, @preview)
        end
      end
    
      private
    
      def update_preview(view)
        if @mouse_ip.valid?
          point = @mouse_ip.position
          normal = @mouse_ip.face ? @mouse_ip.face.normal : Z_AXIS
          transform = Geom::Transformation.new(point, normal)
        
          @preview = [
            transform * [0, 0, 0],
            transform * [@largeur, 0, 0],
            transform * [@largeur, @hauteur, 0],
            transform * [0, @hauteur, 0]
          ]
        else
          @preview = nil
        end
      end
    
      def create_paroi(view)
        model = view.model
        model.start_operation('Créer Nouvelle Paroi', true)
        
        face = model.active_entities.add_face(@preview)
        
        selection = model.selection
        selection.clear
        selection.add(face)
        PEBExpress.appliquer_nom_et_couleur(@type, @indice, @nom_paroi, @angle, @espace_adjacent, @etat_paroi)

        model.commit_operation

        # Incrémente le nom de la paroi après la création
        @nom_paroi = PEBExpress.incrementer_nom_paroi(@nom_paroi)

        # Mise à jour de l'interface avec le nouveau nom
        if @dialog_crea_paroi
          @dialog_crea_paroi.execute_script("updateNomParoi('#{@nom_paroi}')")
        end

        view.model.select_tool(nil)
      end
    
      def update_ui
        Sketchup.status_text = "Cliquez pour placer la nouvelle paroi. Dimensions : #{@largeur / 1.m}m x #{@hauteur / 1.m}m"
      end
    end

    def self.lancer_script
      if @dialog_crea_paroi && @dialog_crea_paroi.visible?
        @dialog_crea_paroi.bring_to_front
      else
        creer_dialogue
      end
    end

    def self.create_toolbar
      toolbar = UI::Toolbar.new "Création paroi"

      cmd = UI::Command.new("Création paroi") {
        if @dialog_crea_paroi && @dialog_crea_paroi.visible?
          @dialog_crea_paroi.bring_to_front
        else
          creer_dialogue
        end
      }
      cmd.small_icon = File.join(__dir__, 'default_small_paroi_icon.png')
      cmd.large_icon = File.join(__dir__, 'default_large_paroi_icon.png')
      cmd.tooltip = "Création paroi"
      cmd.status_bar_text = "Ajouter ou colorer paroi"
      cmd.menu_text = "Ajouter ou colorer paroi"
      toolbar = toolbar.add_item cmd

      toolbar.show
    end

    unless file_loaded?(__FILE__)
      self.create_toolbar
    end

    file_loaded(__FILE__)
  end
end