package io.github.yglukhov.nimx;
import org.libsdl.app.SDLActivity;

public class NimxActivity extends SDLActivity {

	@Override
	// For disabling include of dynamic SDL library file.
	// It's statically linked now.
	protected String[] getLibraries() {
        return new String[] {"main"};
    }
}
