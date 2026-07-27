import os
import sys
from google import genai
from google.genai import types

def get_godot_project_context(root_dir="."):
    """Analyse uniquement les scripts GDScript (.gd) pour alléger la charge de tokens."""
    codebase = {}
    valid_extensions = (".gd",) # Filtrage strict sur les fichiers de code
    ignore_dirs = {".git", ".godot", "export", "addons"}

    for dirpath, dirnames, filenames in os.walk(root_dir):
        dirnames[:] = [d for d in dirnames if d not in ignore_dirs]
        for file in filenames:
            if file.endswith(valid_extensions):
                full_path = os.path.join(dirpath, file)
                try:
                    with open(full_path, "r", encoding="utf-8") as f:
                        codebase[full_path] = f.read()
                except Exception:
                    pass
    return codebase

def main():
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("❌ Erreur : Clé GEMINI_API_KEY introuvable.", file=sys.stderr)
        sys.exit(1)

    print("🔍 Analyse optimisée des scripts de Candela 2D...")
    project_files = get_godot_project_context()

    system_instruction = (
        "Tu es un agent assistant expert en GDScript et sur le moteur Godot.\n"
        "Tu travailles sur le projet de jeu vidéo 'Candela 2D'.\n"
        "Voici le code source des scripts GDScript du projet :\n\n"
    )
    for path, content in project_files.items():
        system_instruction += f"--- FICHIER : {path} ---\n{content}\n\n"

    client = genai.Client(api_key=api_key)
    
    chat = client.chats.create(
        model="gemini-2.0-flash",
        config=types.GenerateContentConfig(
            system_instruction=system_instruction,
            temperature=0.2,
        )
    )

    print("\n" + "="*50)
    print("🔥 AGENT CANDELA-DEV PRÊT (Gemini 2.5 Flash)")
    print("Posez vos questions sur le projet. Tapez 'exit' ou 'quit' pour fermer.")
    print("="*50 + "\n")

    while True:
        try:
            user_input = input("Candela-Dev > ").strip()
            if not user_input:
                continue
            if user_input.lower() in ("exit", "quit"):
                print("Fermeture de la session Candela-Dev. Bon dev !")
                break

            response = chat.send_message(user_input)
            print(f"\n🤖 Agent :\n{response.text}\n")
            print("-" * 50)
        except (KeyboardInterrupt, EOFError):
            print("\nFermeture de la session.")
            break
        except Exception as e:
            print(f"\n❌ Erreur API : {e}\n")

if __name__ == "__main__":
    main()
