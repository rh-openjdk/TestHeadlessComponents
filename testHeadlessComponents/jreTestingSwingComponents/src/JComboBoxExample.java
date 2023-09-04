import javax.swing.JComboBox;

public class JComboBoxExample extends CompatibleComponent {

    @Override
    public void startCreation(){
        System.out.println("Creating combobox");
        String option[]={"1", "2", "3", "4"};
        JComboBox cb=new JComboBox(option);
        System.out.println("Combobox was created");
    }
}
