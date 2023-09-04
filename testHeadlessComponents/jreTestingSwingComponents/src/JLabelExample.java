import javax.swing.JLabel;

public class JLabelExample extends CompatibleComponent {

    @Override
    public void startCreation() {

        System.out.println("Creating a label");
        JLabel label = new JLabel("I am a Label");
        System.out.println("Label was created");

    }
}
