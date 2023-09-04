import javax.swing.JButton;

public class JButtonExample extends CompatibleComponent {

    @Override
    public void startCreation() {

        System.out.println("Creating JButton");
        JButton button = new JButton("I am a button");
        System.out.println("JButton was created");

    }
}
