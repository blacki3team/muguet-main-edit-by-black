package ch.cclerc.muguet;

import android.app.Activity;
import android.content.Intent;
import android.net.Uri;
import android.os.AsyncTask;
import android.os.Bundle;
import android.os.Environment;
import android.util.Log;
import android.view.View;
import android.widget.*;
import org.json.JSONObject;

import java.io.*;

public class LauncherActivity extends Activity {
    private static final String TAG = "MuguetLauncher";
    private static final int REQ_IMPORT_ZIP = 1001;

    private TextView tvStatus;
    private ProgressBar progressBar;
    private Button btnImport;
    private RadioGroup rgMode;
    private Spinner spinnerPreset;
    private SeekBar sbScale;
    private TextView tvScale;
    private SeekBar sbSens;
    private TextView tvSens;
    private CheckBox cbShowFps;
    private CheckBox cbMute;
    private EditText etServerIp;
    private CheckBox cbHost;
    private Button btnLaunch;

    private boolean nativeAvailable = false;

    static {
        try {
            System.loadLibrary("muguet");
        } catch (UnsatisfiedLinkError e) {
            Log.w(TAG, "Native library not loaded yet: " + e.getMessage());
        }
    }

    public static native boolean isGameReady();
    public static native boolean hasGameCode();
    public static native boolean importGame(String zipPath);

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        setContentView(R.layout.activity_launcher);

        try {
            nativeAvailable = true;
        } catch (Exception e) {
            nativeAvailable = false;
        }

        initViews();
        loadConfig();
        checkGameStatus();
    }

    private void initViews() {
        tvStatus = findViewById(R.id.tvStatus);
        progressBar = findViewById(R.id.progressBar);
        btnImport = findViewById(R.id.btnImport);
        rgMode = findViewById(R.id.rgMode);
        spinnerPreset = findViewById(R.id.spinnerPreset);
        sbScale = findViewById(R.id.sbScale);
        tvScale = findViewById(R.id.tvScale);
        sbSens = findViewById(R.id.sbSens);
        tvSens = findViewById(R.id.tvSens);
        cbShowFps = findViewById(R.id.cbShowFps);
        cbMute = findViewById(R.id.cbMute);
        etServerIp = findViewById(R.id.etServerIp);
        cbHost = findViewById(R.id.cbHost);
        btnLaunch = findViewById(R.id.btnLaunch);

        // Presets Spinner setup
        String[] presets = new String[]{
            getString(R.string.preset_balanced),
            getString(R.string.preset_battery),
            getString(R.string.preset_quality),
            getString(R.string.preset_max),
            getString(R.string.preset_custom)
        };
        ArrayAdapter<String> adapter = new ArrayAdapter<>(this, android.R.layout.simple_spinner_dropdown_item, presets);
        spinnerPreset.setAdapter(adapter);

        spinnerPreset.setOnItemSelectedListener(new AdapterView.OnItemSelectedListener() {
            @Override
            public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
                switch (position) {
                    case 0: // Balanced
                        sbScale.setProgress(50);
                        break;
                    case 1: // Battery
                        sbScale.setProgress(35);
                        break;
                    case 2: // Quality
                        sbScale.setProgress(75);
                        break;
                    case 3: // Max
                        sbScale.setProgress(100);
                        break;
                }
            }

            @Override
            public void onNothingSelected(AdapterView<?> parent) {}
        });

        sbScale.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                int p = Math.max(25, progress);
                tvScale.setText(getString(R.string.scale_label, p));
            }
            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {}
            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {}
        });

        sbSens.setOnSeekBarChangeListener(new SeekBar.OnSeekBarChangeListener() {
            @Override
            public void onProgressChanged(SeekBar seekBar, int progress, boolean fromUser) {
                float sens = Math.max(5, progress) / 10.0f;
                tvSens.setText(getString(R.string.sens_label, sens));
            }
            @Override
            public void onStartTrackingTouch(SeekBar seekBar) {}
            @Override
            public void onStopTrackingTouch(SeekBar seekBar) {}
        });

        btnImport.setOnClickListener(v -> pickZipFile());

        btnLaunch.setOnClickListener(v -> {
            saveConfig();
            launchGame();
        });
    }

    private File getGameRootDir() {
        File ext = getExternalFilesDir(null);
        if (ext != null) {
            return ext;
        }
        return new File(Environment.getExternalStorageDirectory(), "Android/data/ch.cclerc.muguet/files");
    }

    private void checkGameStatus() {
        boolean ready = false;
        try {
            if (nativeAvailable) {
                ready = isGameReady();
            }
        } catch (UnsatisfiedLinkError e) {
            // fallback file checking
        }

        if (!ready) {
            File manifest = new File(getGameRootDir(), "game/data/manifest.json");
            File oldManifest = new File(getGameRootDir(), "game/gamedat/data/manifest.json");
            ready = manifest.exists() || oldManifest.exists();
        }

        if (ready) {
            tvStatus.setText(R.string.status_ready);
            tvStatus.setTextColor(getResources().getColor(R.color.accent_green));
            btnLaunch.setEnabled(true);
        } else {
            tvStatus.setText(R.string.status_missing);
            tvStatus.setTextColor(getResources().getColor(R.color.text_secondary));
        }
    }

    private void pickZipFile() {
        Intent intent = new Intent(Intent.ACTION_OPEN_DOCUMENT);
        intent.addCategory(Intent.CATEGORY_OPENABLE);
        intent.setType("*/*");
        startActivityForResult(intent, REQ_IMPORT_ZIP);
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        super.onActivityResult(requestCode, resultCode, data);
        if (requestCode == REQ_IMPORT_ZIP && resultCode == RESULT_OK && data != null) {
            Uri uri = data.getData();
            if (uri != null) {
                new ImportTask().execute(uri);
            }
        }
    }

    private class ImportTask extends AsyncTask<Uri, Integer, Boolean> {
        @Override
        protected void onPreExecute() {
            progressBar.setVisibility(View.VISIBLE);
            progressBar.setIndeterminate(true);
            btnImport.setEnabled(false);
            tvStatus.setText("Importing game files, please wait...");
        }

        @Override
        protected Boolean doInBackground(Uri... uris) {
            Uri uri = uris[0];
            File tempZip = new File(getCacheDir(), "imported_game.zip");
            try {
                // Copy stream from URI to cache file
                InputStream is = getContentResolver().openInputStream(uri);
                if (is == null) return false;
                FileOutputStream fos = new FileOutputStream(tempZip);
                byte[] buffer = new byte[64 * 1024];
                int read;
                while ((read = is.read(buffer)) != -1) {
                    fos.write(buffer, 0, read);
                }
                fos.flush();
                fos.close();
                is.close();

                // Call native importer if available
                boolean success = false;
                try {
                    if (nativeAvailable) {
                        success = importGame(tempZip.getAbsolutePath());
                    }
                } catch (UnsatisfiedLinkError e) {
                    Log.e(TAG, "Native import failed: " + e.getMessage());
                }

                if (!success) {
                    // Java extraction fallback
                    File dest = new File(getGameRootDir(), "game");
                    dest.mkdirs();
                    success = unzip(tempZip, dest);
                }

                tempZip.delete();
                return success;
            } catch (Exception e) {
                Log.e(TAG, "Error importing: " + e.getMessage(), e);
                return false;
            }
        }

        @Override
        protected void onPostExecute(Boolean success) {
            progressBar.setVisibility(View.GONE);
            btnImport.setEnabled(true);
            if (success) {
                Toast.makeText(LauncherActivity.this, "Import succeeded!", Toast.LENGTH_LONG).show();
            } else {
                Toast.makeText(LauncherActivity.this, "Import failed: Check zip format", Toast.LENGTH_LONG).show();
            }
            checkGameStatus();
        }
    }

    private boolean unzip(File zipFile, File targetDir) {
        try (java.util.zip.ZipInputStream zis = new java.util.zip.ZipInputStream(new FileInputStream(zipFile))) {
            java.util.zip.ZipEntry ze;
            byte[] buf = new byte[64 * 1024];
            while ((ze = zis.getNextEntry()) != null) {
                File file = new File(targetDir, ze.getName());
                if (ze.isDirectory()) {
                    file.mkdirs();
                } else {
                    File parent = file.getParentFile();
                    if (parent != null) parent.mkdirs();
                    try (FileOutputStream fos = new FileOutputStream(file)) {
                        int count;
                        while ((count = zis.read(buf)) != -1) {
                            fos.write(buf, 0, count);
                        }
                    }
                }
                zis.closeEntry();
            }
            return true;
        } catch (Exception e) {
            Log.e(TAG, "Unzip error: " + e.getMessage());
            return false;
        }
    }

    private void loadConfig() {
        File cfg = new File(getGameRootDir(), "config.json");
        if (!cfg.exists()) return;
        try (BufferedReader br = new BufferedReader(new FileReader(cfg))) {
            StringBuilder sb = new StringBuilder();
            String line;
            while ((line = br.readLine()) != null) sb.append(line);
            JSONObject json = new JSONObject(sb.toString());

            if (json.has("scale")) {
                int scale = (int) (json.getDouble("scale") * 100);
                sbScale.setProgress(scale);
            }
            if (json.has("touch_sensitivity")) {
                int sens = (int) (json.getDouble("touch_sensitivity") * 10);
                sbSens.setProgress(sens);
            }
            if (json.has("start_mode")) {
                int mode = json.getInt("start_mode");
                if (mode == 1) rgMode.check(R.id.rbStory);
                else rgMode.check(R.id.rbSandbox);
            }
            if (json.has("mute")) cbMute.setChecked(json.getBoolean("mute"));
            if (json.has("show_fps")) cbShowFps.setChecked(json.getBoolean("show_fps"));
            if (json.has("multiplayer")) cbHost.setChecked(json.optBoolean("host", false));
            if (json.has("server")) etServerIp.setText(json.getString("server"));
        } catch (Exception e) {
            Log.w(TAG, "Error loading config: " + e.getMessage());
        }
    }

    private void saveConfig() {
        File root = getGameRootDir();
        root.mkdirs();
        File cfg = new File(root, "config.json");
        try {
            JSONObject json = new JSONObject();
            double scale = sbScale.getProgress() / 100.0;
            double sens = sbSens.getProgress() / 10.0;
            int mode = rgMode.getCheckedRadioButtonId() == R.id.rbStory ? 1 : 2;

            json.put("scale", scale);
            json.put("touch_sensitivity", sens);
            json.put("start_mode", mode);
            json.put("fullscreen", true);
            json.put("mute", cbMute.isChecked());
            json.put("show_fps", cbShowFps.isChecked());
            json.put("multiplayer", cbHost.isChecked() || !etServerIp.getText().toString().trim().isEmpty());
            json.put("host", cbHost.isChecked());
            json.put("server", etServerIp.getText().toString().trim());

            try (FileWriter fw = new FileWriter(cfg)) {
                fw.write(json.toString(2));
            }
        } catch (Exception e) {
            Log.e(TAG, "Error saving config: " + e.getMessage());
        }
    }

    private void launchGame() {
        Intent intent = new Intent(this, GameActivity.class);
        intent.putExtra("DATA_DIR", getGameRootDir().getAbsolutePath());
        startActivity(intent);
    }
}
