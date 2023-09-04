import javax.swing.JCheckBox;

public class JCheckBoxExample extends CompatibleComponent {

    @Override
    public void startCreation() {

        System.out.println("Creating JCheckBox");
        JCheckBox checkBox = new JCheckBox("checkbox", true);
        checkBox.setBounds(100,150, 50,50);
        System.out.println("JCheckBox created");

    }
}
