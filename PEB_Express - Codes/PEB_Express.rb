=begin

Copyright 2024, Author 
All Rights Reserved

License: AuthorsLicenseStatement 
Author: Guisse Julien
Name: PEB Express
Version: 0.0.1
SU Version: 2017 
Date: 27/08/24
Description: Suite de programmes pour l'encodage PEB 
Usage: ScriptUsageInstructions 
History:
    0.0.1 2024-08-24 Première version sortie
    
=end

require 'sketchup.rb'
require 'extensions.rb'

# Wrap in your own module. Start its name with a capital letter

module Guisse

  module PEBExpress

    # Load extension
    my_extension_loader = SketchupExtension.new( 'PEB Express' , 'src/PEBExpress.rb' )
    my_extension_loader.copyright = 'Copyright 2024 by GUISSE Julien' 
    my_extension_loader.creator = 'Guisse Julien' 
    my_extension_loader.version = '1.0.0' 
    my_extension_loader.description = 'Extension Sketch Up conçue pour l''encodage PEB en Belgique'
    Sketchup.register_extension( my_extension_loader, true )

  end  
  
end  