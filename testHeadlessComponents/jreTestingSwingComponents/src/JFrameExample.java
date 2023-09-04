import javax.swing.*;
import java.awt.*;

public class JFrameExample extends IncompatibleComponent {
    static JFrame f;

    @Override
    public void startCreation() {

        System.out.println("Creating JFrame");
	f = new JFrame();
        System.out.println("JFrame created");
	f.setVisible(true);
	System.out.println("JFrame visible");
    }
}
