import javax.swing.*;
import java.awt.*;

public class JDialogExample extends IncompatibleComponent {
    static JDialog d;

    @Override
    public void startCreation() {

        System.out.println("Creating JDialog");
	d = new JDialog();
        System.out.println("JDialog created");
	d.setVisible(true);
	System.out.println("JDialog visible");
    }
}
