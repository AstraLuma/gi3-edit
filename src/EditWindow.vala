using Gtk;
using Gdk;

namespace Mark {
    class EditWindow : ApplicationWindow {
        private SourceView svText;
        private ScrolledWindow swText;
        
        private SourceBuffer sbData;
        
        private SourceLanguageManager slman;
        private SourceStyleSchemeManager sssman;
        
        public CommandPalette? command_palette {get; set construct;}
        
        public bool dirty { get {
            return true; // FIXME
        }}
        
        public string? etag {get; private set;}
        public SourceFile source {get; construct;}
        
        public EditWindow(Gtk.Application application, CommandPalette? cp=null) {
            Object(
                application: application, 
                show_menubar: false, 
                command_palette: cp,
                source: new SourceFile()
            );
        }

        public EditWindow.with_file(Gtk.Application application, CommandPalette? cp=null, File file) {
            Object(
                application: application, 
                show_menubar: false, 
                command_palette: cp,
                source: new SourceFile()
            );
            
            // Load file
            this.source.location = file;
            var sfl = new SourceFileLoader(sbData, source);
            sfl.load_async.begin(0, null, (cur, total) => {
                stdout.printf(@"Loading $(cur)/$(total)\n");
            }, () => {
                stdout.printf(@"Guessing language...\n");
                var lang = slman.guess_language(file.get_uri(), sbData.text);
                if (lang != null) {
                    stdout.printf(@"\t$(lang.get_name())\n");
                    sbData.language = lang;
                } else {
                    stdout.printf("\tDunno.\n");
                }
            });
       }
       
       private void build_ui() {
            this.title = Environment.get_application_name();

            swText = new ScrolledWindow(null, null);
            this.add(swText);
            
            svText = new SourceView();
            // Defaults for code editing
            svText.auto_indent = true;
            svText.highlight_current_line = true;
            svText.indent_on_tab = true;
            svText.indent_width = 4;
            svText.insert_spaces_instead_of_tabs = true;
            svText.show_line_marks = true;
            svText.show_line_numbers = true;
            svText.smart_home_end = SourceSmartHomeEndType.BEFORE;
            // TODO: Do this in CSS
            svText.override_font(Pango.FontDescription.from_string(monofont()));
            swText.add(svText);
            
            sbData = svText.buffer as SourceBuffer;
            assert(sbData != null);
            sbData.highlight_matching_brackets = true;
            sbData.highlight_syntax = true;
            // TODO: Have this in an option or action
            sbData.style_scheme = sssman.get_scheme("classic");
            foreach (var scheme in sssman.get_scheme_ids()) {
                stdout.printf(@"Scheme: $scheme\n");
            }
        }
        
        private void populate_actions() {
            this.destroy.connect(() => {
                if (command_palette != null) {
                    command_palette.remove_action_group(this);
                }
            });
            
            this.add_action(mkaction("save", do_save));
            this.add_action(mkaction("save-as", do_save_as));
            // TODO: All the languages
        }
                
        construct {
            slman = SourceLanguageManager.get_default();
            sssman = SourceStyleSchemeManager.get_default();
            
            build_ui();
            
            this.notify["command-palette"].connect((_) => {
                // FIXME: Remove ourselves from the previous group
                command_palette.add_action_group(this);
            });
            
            populate_actions();
        }
                
        private void do_save() {
            if (source.location == null) {
                // Hasn't been saved. Do the save as process, but use the 
                // location it got saved to as the document's location.
                source.location = real_save_as();
                return;
            }
            stdout.printf("Save!\n");
            save_to(source.location);
        }
        
        private void do_save_as() {
            real_save_as();
        }
        
        /**
         * All the work of Save As, but returns where it got saved to, or null 
         * if the user cancelled.
         */
        private File? real_save_as() {
            stdout.printf("Save as...\n");
            return null;
            // 1. Prompt for file
            // 2. save_to(file)
        }
        
        /**
         * Writes out to the given file.
         */
        private void save_to(File dest) {
        }
        
    }
}
