import * as path from "path";
import { workspace, ExtensionContext } from "vscode";
import {
    LanguageClient,
    LanguageClientOptions,
    ServerOptions,
    TransportKind
} from "vscode-languageclient/node";

let client: LanguageClient;

export async function activate(context: ExtensionContext) {
    const serverModule = context.asAbsolutePath(
        path.join("server", "out", "server.js")
    );
    const debugOptions = { execArgv: ["--nolazy", "--inspect=6009"] };

    const serverOptions: ServerOptions = {
        run: { module: serverModule, transport: TransportKind.ipc },
        debug: {
            module: serverModule,
            transport: TransportKind.ipc,
            options: debugOptions
        }
    };

    const clientOptions: LanguageClientOptions = {
        documentSelector: [{ scheme: "file", language: "l25" }],
        synchronize: {
            fileEvents: workspace.createFileSystemWatcher("**/*.l25")
        }
    };

    client = new LanguageClient(
        "l25LanguageServer",
        "L25 Language Server",
        serverOptions,
        clientOptions
    );

    context.subscriptions.push(client.start());
}

export function deactivate(): Thenable<void> | undefined {
    if (!client) {
        return undefined;
    }
    return client.stop();
}
