package dev.geode.geode_native;

import android.content.Context;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

/** projectM needs real paths; extract bundled presets atomically into private storage. */
final class MilkAssets {
    private MilkAssets() {}

    static List<String> presets(Context context) throws IOException {
        String[] entries = context.getAssets().list("milk");
        if (entries == null) return List.of();
        return Arrays.stream(entries).filter(name -> name.endsWith(".milk")).sorted().collect(Collectors.toList());
    }

    static File extract(Context context, String name) throws IOException {
        if (!presets(context).contains(name)) throw new IOException("Unknown bundled MilkDrop preset: " + name);
        File directory = new File(context.getFilesDir(), "milk");
        if (!directory.isDirectory() && !directory.mkdirs()) throw new IOException("Cannot create preset directory");
        File file = new File(directory, name);
        File temporary = File.createTempFile("preset-", ".tmp", directory);
        try {
            try (InputStream input = context.getAssets().open("milk/" + name);
                 FileOutputStream output = new FileOutputStream(temporary)) {
                byte[] buffer = new byte[16384];
                int count;
                while ((count = input.read(buffer)) != -1) output.write(buffer, 0, count);
                output.getFD().sync();
            }
            if (!temporary.renameTo(file)) throw new IOException("Cannot install MilkDrop preset");
            return file;
        } finally {
            if (temporary.exists()) temporary.delete();
        }
    }
}
